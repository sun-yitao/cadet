defmodule Cadet.CodeMetrics.LambdaWorker do
  @moduledoc """
  This module submits the answer to the autograder and creates a job for the ResultStoreWorker to
  write the received result to db.
  """
  use Que.Worker, concurrency: 20

  require Logger

  alias Cadet.Autograder.ResultStoreWorker

  @lambda_name :cadet |> Application.fetch_env!(:codemetrics) |> Keyword.get(:lambda_name)

  @doc """
  This Que callback transforms an input of %{question: %Question{}, answer: %Answer{}} into
  the correct shape to dispatch to lambda, waits for the response, parses it, and enqueues a
  storage job.
  """
  def perform(params = %{student_program: student_program}) do
    lambda_params = params
    response =
      @lambda_name
      |> ExAws.Lambda.invoke(lambda_params, %{})
      |> ExAws.request!()

    result = parse_response(response)

    #Que.add(ResultStoreWorker, %{answer_id: answer.id, result: result})
  end

  defp parse_response(response) when is_map(response) do
    # If the lambda crashes, results are in the format of:
    # %{"errorMessage" => "${message}"}
    if Map.has_key?(response, "errorMessage") do
      %{
        grade: 0,
        status: :failed,
        result: [
          %{
            "resultType" => "error",
            "errors" => [
              %{"errorType" => "systemError", "errorMessage" => response["errorMessage"]}
            ]
          }
        ]
      }
    else
      %{codeLength: response["codeLength"], codeMetric2: response["codeMetric2"], codeMetric3: response["codeMetric3"], status: :success}
    end
  end
end
