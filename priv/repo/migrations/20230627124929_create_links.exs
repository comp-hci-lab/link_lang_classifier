defmodule LinkLangClassifier.Repo.Migrations.CreateLinks do
  use Ecto.Migration

  def change do
    create table(:links) do
      add :url, :string
      add :classifier_id, references(:users)
      timestamps()
    end

    create table(:classifications) do
      add :category, :string
      add :link_id, references(:links)
      #two foreign keys classifier_id (unique constraint) (references)
      timestamps()
    end

    create table(:ethnicity_classifications) do
      add :is_slavic, :boolean
      add :is_kyrgyz, :boolean
      add :is_other_central_asian, :boolean
      add :is_caucasian, :boolean
      add :is_other, :boolean
      add :is_no_people, :boolean
      add :is_unreachable, :boolean
      add :link_id, references(:links)
      timestamps()
    end

    create table(:language_classifications) do
      add :is_russian, :boolean
      add :is_kyrgyz, :boolean
      add :is_english, :boolean
      add :is_unknown, :boolean
      add :is_unreachable, :boolean
      add :is_no_language, :boolean
      add :other_lang, :string
      add :link_id, references(:links)
      timestamps()
    end


    create (
      unique_index(
        :links,
         [:classifier_id,:url]
        )
      )
  end
end
