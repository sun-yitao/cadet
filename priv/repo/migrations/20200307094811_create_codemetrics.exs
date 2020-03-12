defmodule Cadet.Repo.Migrations.CreateCodeMetrics do
  use Ecto.Migration

  def change do
    create table(:codemetrics) do
      add(:assessment_id, references(:assessments), null: false)
      add(:question_id, references(:questions), null: false)
      add(:student_id, references(:users), null: false)
      add(:code_length, :integer, default: 0)
      timestamps()
    end

    create(unique_index(:codemetrics, [:assessment_id, :question_id, :student_id]))
  end
end
