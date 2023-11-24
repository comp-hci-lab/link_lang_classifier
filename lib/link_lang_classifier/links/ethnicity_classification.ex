defmodule LinkLangClassifier.Links.EthnicityClassification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ethnicity_classifications" do
    field :is_slavic, :boolean
    field :is_kyrgyz, :boolean
    field :is_other_central_asian, :boolean
    field :is_caucasian, :boolean
    field :is_other, :boolean
    field :is_no_people, :boolean
    field :is_unreachable, :boolean
    field :link_id, :integer
    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:is_slavic,:is_kyrgyz, :is_other_central_asian, :is_caucasian, :is_other, :is_no_people, :is_unreachable, :link_id])
    |> validate_required([:is_slavic,:is_kyrgyz, :is_other_central_asian, :is_caucasian, :is_other, :is_no_people, :is_unreachable, :link_id])

  end
end
