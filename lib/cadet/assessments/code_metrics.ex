defmodule Cadet.Assessments.CodeMetrics do
  @moduledoc false
  use Cadet, :model

  alias Cadet.Accounts.User
  alias Cadet.Assessments.{Answer, Assessment, SubmissionStatus, Question}

  schema "codemetrics" do
    field(:code_length, :integer)
    field(:status, SubmissionStatus, default: :attempting)

    belongs_to(:assessment, Assessment)
    belongs_to(:student, User)
    belongs_to(:question, Question)
    belongs_to(:answers, Answer)

    timestamps()
  end

  @required_fields ~w(student_id assessment_id question_id code_length)a
  @optional_fields ~w()a

  def changeset(submission, params) do
    submission
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_number(
      :code_length,
      greater_than_or_equal_to: 0
    )
    |> add_belongs_to_id_from_model([:student, :assessment, :question, :answers], params)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:student_id)
    |> foreign_key_constraint(:assessment_id)
    |> foreign_key_constraint(:question_id)
    |> foreign_key_constraint(:answer_id)
  end
end
