defmodule Cadet.CodeMetrics.ResultStoreWorker do
  @moduledoc """
  This module writes results from the autograder to db. Separate worker is created with lower
  concurrency on the assumption that autograding time >> db IO time so as to reduce db load.
  """
  use Que.Worker, concurrency: 5

  require Logger

  import Cadet.SharedHelper
  import Ecto.Query

  alias Ecto.Multi

  alias Cadet.Repo
  alias Cadet.Assessments.CodeMetrics

  def perform(%{answer_id: answer_id, result: result}) when is_ecto_id(answer_id) do #result is of form %{codeLength: 57, codeMetric2: 0, codeMetric3: 0, status: :success}
    Multi.new()
    |> Multi.run(:fetch, fn _repo, _ -> fetch_codemetrics(answer_id) end)
    |> Multi.run(:update, fn _repo, %{fetch: codemetrics} -> update_codemetrics(codemetrics, result) end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        nil

      {:error, failed_operation, failed_value, _} ->
        error_message =
          "Failed to store autograder result. " <>
            "answer_id: #{answer_id}, #{failed_operation}, #{inspect(failed_value, pretty: true)}"

        Logger.error(error_message)
        Sentry.capture_message(error_message)
    end
  end

  defp fetch_codemetrics(answer_id) when is_ecto_id(answer_id) do
    codemetrics = Repo.get(CodeMetrics, answer_id)

    if codemetrics do
      {:ok, codemetrics}
    else
      {:error, "Answer not found"}
    end
  end

  defp update_codemetrics(codemetrics = %CodeMetrics{}, result = %{status: status}) do

    changes = %{
      code_length: result.codeLength,
    }

    codemetrics
    |> CodeMetrics.changeset(changes)
    |> Repo.update()
  end
end
