defmodule LinkLangClassifierWeb.ClassifierLive.Index do
  use LinkLangClassifierWeb, :live_view
  alias LinkLangClassifier.Finch, as: MyFinch

  @default_map %{
    "ru" => %{is_checked: false, name: "Russian"},
    "en" => %{is_checked: false, name: "English"},
    "kg" => %{is_checked: false, name: "Kyrgyz"}
  }

  @impl true
  def mount(_params, _session, socket) do
    langs = @default_map
    user_id = socket.assigns.current_user.id
    result = get_next_link(user_id)
    links_count = count_progress(user_id)
    payment_count = count_payment(user_id)

    {:ok,
     assign(socket,
       langs: langs,
       links_count: links_count,
       payment_count: payment_count,
       link: result,
       text_value: "",
       none_isChecked: false,
       other_isChecked: false
     ), layout: false}
  end

  def get_next_link(user_id) do
    # 1. Get next link from DB
    with %LinkLangClassifier.Links.Link{} = link <-
           LinkLangClassifier.Links.get_next_unclassified(user_id) do
      # 2. Fetch the html by url with Finch
      {:ok, %{body: html}} =
        Finch.build(:get, link.url)
        |> Finch.request(MyFinch)

      # 3. Parse HTML and get required tags
      {:ok, required_tags} = parse_html(html)
      all_tags = Floki.find(required_tags, "meta")

      IO.inspect(all_tags)
      # 4. Put the required fields to a map and return
      all_tags
      |> Enum.map(fn {_, list, _} -> list end)
      |> Enum.filter(fn [{name, _} | _] -> name == "property" end)
      |> Enum.reduce(%{id: link.id, url: link.url}, &property_reducer/2)
    end
  end

  def count_progress(user_id) do
    (LinkLangClassifier.Links.count_classifications(user_id) /
       LinkLangClassifier.Links.count_links() * 100)
    |> Decimal.from_float()
    |> Decimal.round(2)
  end

  def count_payment(user_id) do
    (LinkLangClassifier.Links.count_classifications(user_id) * 0.1)
    |> Decimal.from_float()
    |> Decimal.round(2)
  end

  defp parse_html(html) do
    Floki.parse_document(html)
  end

  defp property_reducer(list, acc) do
    {_, p_name} = hd(list)
    [{"content", val} | _] = tl(list)

    case p_name do
      "og:title" -> Map.put(acc, :title, val)
      # "og:description" -> Map.put(acc, :desc, val)
      "og:video:url" -> Map.put(acc, :video, val)
      _ -> acc
    end
  end

  def handle_event("other-event", %{"value" => other_text}, socket) do
    other_isChecked = not socket.assigns.other_isChecked
    none_isChecked = if other_isChecked, do: false, else: socket.assigns.none_isChecked
    IO.inspect(other_isChecked)
    {:noreply, assign(socket, other_isChecked: other_isChecked, none_isChecked: none_isChecked)}
  end

  def handle_event("none-btn-event", %{"value" => other_text}, socket) do
    none_isChecked = not socket.assigns.none_isChecked
    other_isChecked = if none_isChecked, do: false, else: socket.assigns.other_isChecked
    langs = if none_isChecked, do: @default_map, else: socket.assigns.langs
    IO.inspect(other_isChecked)

    {:noreply,
     assign(socket,
       other_isChecked: other_isChecked,
       none_isChecked: none_isChecked,
       langs: langs
     )}
  end

  def handle_event("other-change", %{"value" => msg}, socket) do
    IO.inspect(msg)
    {:noreply, assign(socket, text_value: msg)}
  end

  @impl true
  def handle_event("submit-event", %{"id" => id}, socket) do
    {id, _} = Integer.parse(id)

    langs = socket.assigns.langs

    res =
      langs
      |> Enum.filter(fn {_, %{is_checked: checked_value}} ->
        checked_value
      end)
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.sort()
      |> Enum.join("/")

    none_isChecked = socket.assigns.none_isChecked
    res = if none_isChecked, do: "none", else: res

    other_isChecked = socket.assigns.other_isChecked
    res = if other_isChecked && res != "", do: res <> "|" <> socket.assigns.text_value, else: res
    res = if other_isChecked && res == "", do: socket.assigns.text_value, else: res

    user_id = socket.assigns.current_user.id

    case res do
      "" ->
        {:noreply, put_flash(socket, :error, "Language is not choosen")}

      lang ->
        id
        |> LinkLangClassifier.Links.classify(lang, user_id)

        result = get_next_link(user_id)
        socket = put_flash(socket, :info, "Classified successfully.")
        new_links_count = count_progress(user_id)
        new_payment_count = count_payment(user_id)

        {:noreply,
         assign(socket,
           link: result,
           langs: @default_map,
           none_isChecked: false,
           other_isChecked: false,
           links_count: new_links_count,
           payment_count: new_payment_count
         )}
    end
  end

  @impl true
  def handle_event("btn-event", %{"lang" => lang}, socket) do
    langs = socket.assigns.langs
    params = Map.get(langs, lang)

    value_checked = Map.get(params, :is_checked)
    IO.inspect(value_checked)
    none_isChecked = if value_checked, do: socket.assigns.none_isChecked, else: false

    new_params = Map.put(params, :is_checked, !value_checked)
    IO.inspect(new_params)

    new_langs = Map.put(langs, lang, new_params)

    IO.inspect(new_langs)
    {:noreply, assign(socket, langs: new_langs, none_isChecked: none_isChecked)}
  end
end
