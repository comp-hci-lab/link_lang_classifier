defmodule LinkLangClassifier.Links.Link do
  use Ecto.Schema
  import Ecto.Changeset

  schema "links" do
    field :url, :string
    field :classifier_id, :integer
    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:url, :classifier_id])
    |> validate_required([:url, :classifier_id])
    |> unique_constraint([:url, :classifier_id])
  end
end
