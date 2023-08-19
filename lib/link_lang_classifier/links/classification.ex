defmodule LinkLangClassifier.Links.Classification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "classifications" do
    field :category, :string
    field :link_id, :integer
    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:category, :link_id])
    |> validate_required([:category, :link_id])
  end
  '''
  schema "classifications" do
    field :category, :string
    field :assignment_id, :integer
    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:category, :assignment_id])
    |> validate_required([:category, :assignment_id])
    |> validate_length(:category,min: 2)  #add min keywoard list  (min 2 char)
    |> unique_constraint([:assignment_id])
  end

  '''
end
