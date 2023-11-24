defmodule LinkLangClassifier.Links.LanguageClassification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "language_classifications" do
    field :is_russian, :boolean
    field :is_kyrgyz, :boolean
    field :is_english, :boolean
    field :is_unknown, :boolean
    field :is_unreachable, :boolean
    field :is_no_language, :boolean
    field :other_lang, :string
    field :link_id, :integer
    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:is_russian, :is_kyrgyz, :is_english, :is_unknown, :is_unreachable, :is_no_language, :other_lang, :link_id])
    |> validate_required([:is_russian, :is_kyrgyz, :is_english, :is_unknown, :is_unreachable, :is_no_language, :link_id])
  end
end
