defmodule LinkLangClassifierWeb.ClassifierLive.Index do
  use LinkLangClassifierWeb, :live_view
  alias LinkLangClassifier.Finch, as: MyFinch


  @default_map %{"ru" => %{is_checked: false, name: "Russian"},"en" => %{is_checked: false, name: "English"},"kg" => %{is_checked: false, name: "Kyrgyz"},
    "unknown" => %{is_checked: false, name: "Unknown Language"},"unreachable" => %{is_checked: false, name: "Video Unavailable"}}

  @submit_button_wait_ms 15000

  @impl true
  def mount(_params, _session, socket) do
    langs = @default_map
    user_id = socket.assigns.current_user.id

    result = get_existing_video(user_id)

    links_count = count_progress(user_id)
    payment_count = count_payment(user_id)

    Process.send_after(self(), {:time_up, true}, @submit_button_wait_ms)

    socket =
      assign(socket,
        langs: langs,
        links_count: links_count,
        payment_count: payment_count,
        link: result,
        text_value: "",
        none_isChecked: false,
        other_isChecked: false,
        time_up: false
      )

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({task_id, return_value}, socket) do
    IO.inspect("handling")

    {:noreply, assign(socket, :time_up, true)}
  end

  def handle_info({_, _, _, _, _} = details, socket) do
    IO.inspect(details)
    {:noreply, socket}
  end

  def get_existing_video(user_id) do
    link = get_next_link(user_id)

    if(link == nil or Map.has_key?(link, :video)) do
      link
    else
      link.id
      |> LinkLangClassifier.Links.classify("non_exist")

      get_existing_video(user_id)
    end
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

      all_tags
      |> Enum.map(fn {_, list, _} -> list end)
      |> Enum.filter(fn [{name, _} | _] -> name == "property" end)
      |> Enum.reduce(%{id: link.id, url: link.url}, &property_reducer/2)
    end
  end


  def count_progress(user_id) do 
    (LinkLangClassifier.Links.count_classifications(user_id) / LinkLangClassifier.Links.count_links(user_id)) * 100 
    |> Decimal.from_float()
    |> Decimal.round(2)
  end

  def count_payment(user_id) do
    (LinkLangClassifier.Links.count_classifications(user_id) * 0.06)
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
      "og:url" ->
        video_hash = get_hash(val)

        video_url = "https://www.youtube.com/embed/" <> video_hash
        Map.put(acc, :video, video_url)

      # "og:title" -> Map.put(acc, :title, val)
      # "og:description" -> Map.put(acc, :desc, val)
      # "og:video:url" ->
      #   Map.put(acc, :video, val)
      _ ->
        acc
    end
  end

  defp get_hash(url) do
    cond do
      String.contains?(url, "watch?v=") ->
        parse_url(url, "watch?v=")

      String.contains?(url, "shorts") ->
        parse_url(url, "shorts")
    end
  end

  defp parse_url(url, args) do
    [_, split_args] = String.split(url, args)

    if(String.contains?(split_args, "&")) do
      [split_asterisk, _] = String.split(url, "&")
      split_asterisk
    else
      split_args
    end
  end

  def handle_event("other-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    other_isChecked = not socket.assigns.other_isChecked
    none_isChecked = if other_isChecked, do: false, else: socket.assigns.none_isChecked

    {:noreply, assign(socket, other_isChecked: other_isChecked, none_isChecked: none_isChecked)}
  end

  def handle_event("none-btn-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    none_isChecked = not socket.assigns.none_isChecked
    other_isChecked = if none_isChecked, do: false, else: socket.assigns.other_isChecked
    langs = if none_isChecked, do: @default_map, else: socket.assigns.langs

    {:noreply,
     assign(socket,
       other_isChecked: other_isChecked,
       none_isChecked: none_isChecked,
       langs: langs
     )}
  end

  def handle_event("other-change", %{"value" => msg}, socket) do
    socket = clear_flash(socket)
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
        {:noreply, put_flash(socket, :error, "Language is not chosen")}

      lang ->
        id

        |> LinkLangClassifier.Links.classify(lang)
        result = get_next_link(user_id)


        result = get_existing_video(user_id)

        socket = put_flash(socket, :info, "Classified successfully.")
        new_links_count = count_progress(user_id)
        new_payment_count = count_payment(user_id)

        Process.send_after(self(), {:time_up, true}, @submit_button_wait_ms)

        {:noreply, assign(socket, link: result, langs: @default_map, payment_count: new_payment_count, links_count: new_links_count, other_isChecked: false, none_isChecked: false, text_value: "", time_up: false)}
    end
  end

  @impl true
  def handle_event("btn-event", %{"lang" => lang}, socket) do
    socket = clear_flash(socket)

    langs = socket.assigns.langs
    params = Map.get(langs, lang)

    value_checked = Map.get(params, :is_checked)
    none_isChecked = if value_checked, do: socket.assigns.none_isChecked, else: false

    new_params = Map.put(params, :is_checked, !value_checked)

    new_langs = Map.put(langs, lang, new_params)

    {:noreply, assign(socket, langs: new_langs, none_isChecked: none_isChecked)}
  end
end
