defmodule Cadet.CodeMetrics.LambdaWorkerTest do
  use Cadet.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  import Mock
  import ExUnit.CaptureLog

  alias Cadet.Assessments.{Answer, Question}
  alias Cadet.CodeMetrics.{LambdaWorker, ResultStoreWorker}

  setup_all do
    # This essentially does :application.ensure_all_started(:hackney)
    HTTPoison.start()
  end

  setup do
    question =
      insert(
        :programming_question,
        %{
          question:
            build(:programming_question_content, %{
              public: [
                %{"score" => 1, "answer" => "1", "program" => "f(1);"}
              ],
              private: [
                %{"score" => 1, "answer" => "45", "program" => "f(10);"}
              ]
            })
        }
      )

    submission =
      insert(:submission, %{
        student: insert(:user, %{role: :student}),
        assessment: question.assessment
      })

    answer =
      insert(:answer, %{
        submission: submission,
        question: question,
        answer: %{code: "const f = i => i === 0 ? 0 : i < 3 ? 1 : f(i-1) + f(i-2);"}
      })

    %{question: question, answer: answer}
  end

  describe "#perform" do
    test "success", %{question: question, answer: answer} do
      LambdaWorker.perform(%{
        question: Repo.get(Question, question.id),
        answer: Repo.get(Answer, answer.id)
      })
    end

    test "submission errors", %{question: question, answer: answer} do
      use_cassette "autograder/errors#1", custom: true do
        with_mock Que, add: fn _, _ -> nil end do
          LambdaWorker.perform(%{
            question: Repo.get(Question, question.id),
            answer: Repo.get(Answer, answer.id)
          })

        end
      end
    end

  end

  describe "on_failure" do
    test "it stores error message", %{question: question, answer: answer} do
      with_mock Que, add: fn _, _ -> nil end do
        error = %{"errorMessage" => "Task timed out after 1.00 seconds"}

        log =
          capture_log(fn ->
            LambdaWorker.on_failure(
              %{question: question, answer: answer},
              inspect(error)
            )
          end)

        assert log =~ "Failed to get autograder result."
        assert log =~ "answer_id: #{answer.id}"
        assert log =~ "Task timed out after 1.00 seconds"

      end
    end
  end

  describe "#build_request_params" do
    test "it should build correct params", %{question: question, answer: answer} do
      expected = %{
        prependProgram: question.question.prepend,
        postpendProgram: question.question.postpend,
        testcases: question.question.public ++ question.question.private,
        studentProgram: answer.answer.code,
        library: %{
          chapter: question.grading_library.chapter,
          external: %{
            name: question.grading_library.external.name |> Atom.to_string() |> String.upcase(),
            symbols: question.grading_library.external.symbols
          },
          globals: Enum.map(question.grading_library.globals, fn {k, v} -> [k, v] end)
        }
      }

      assert LambdaWorker.build_request_params(%{
               question: Repo.get(Question, question.id),
               answer: Repo.get(Answer, answer.id)
             }) == expected
    end
  end
end