defmodule LinkLangClassifierWeb.ClassifierLive.Index do
  use LinkLangClassifierWeb, :live_view
  alias LinkLangClassifier.Finch, as: MyFinch


  @default_lang_map %{"ru" => %{is_checked: false, name: "Russian"},"en" => %{is_checked: false, name: "English"},"kg" => %{is_checked: false, name: "Kyrgyz"},
    "unknown" => %{is_checked: false, name: "Unknown Language"}}

  @default_ethnicity_map %{"sl" => %{is_checked: false, name: "Slavic"},"kg" => %{is_checked: false, name: "Kyrgyz"},"kz" => %{is_checked: false, name: "Kazakh"},
    "unknown" => %{is_checked: false, name: "Other Ethnicity"}}

  @submit_button_wait_ms 15000

  @impl true
  def mount(_params, _session, socket) do
    langs = @default_lang_map
    ppl = @default_ethnicity_map
    user_id = socket.assigns.current_user.id

    result = get_existing_video(user_id)

    links_count = count_progress(user_id)
    payment_count = count_payment(user_id)

    Process.send_after(self(), {:time_up, true}, @submit_button_wait_ms)

    socket =
      assign(socket,
        langs: langs,
        ppl: ppl,
        links_count: links_count,
        payment_count: payment_count,
        link: result,
        text_value: "",
        no_lang_isChecked: false,
        unreachable_isChecked: false,
        other_lang_isChecked: false,
        no_people_isChecked: false,
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
    num_links = LinkLangClassifier.Links.count_links(user_id)
    num_links = if num_links == 0, do: 1, else: num_links
    (LinkLangClassifier.Links.count_classifications(user_id) / num_links) * 100 
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

  def handle_event("btn-ppl-event", %{"pick" => pick}, socket) do
    socket = clear_flash(socket)

    ppl = socket.assigns.ppl
    params = Map.get(ppl, pick)

    value_checked = Map.get(params, :is_checked)
    no_people_isChecked = if value_checked, do: socket.assigns.no_people_isChecked, else: false

    new_params = Map.put(params, :is_checked, !value_checked)

    new_ppl = Map.put(ppl, pick, new_params)

    {:noreply, assign(socket, ppl: new_ppl, no_people_isChecked: no_people_isChecked)}
  end

  def handle_event("other-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    other_lang_isChecked = not socket.assigns.other_lang_isChecked
    no_lang_isChecked = if other_lang_isChecked, do: false, else: socket.assigns.no_lang_isChecked
    unreachable_isChecked = if other_lang_isChecked, do: false, else: socket.assigned.unreachable_isChecked

    {:noreply, assign(socket, other_lang_isChecked: other_lang_isChecked, no_lang_isChecked: no_lang_isChecked, unreachable_isChecked: unreachable_isChecked)}
  end

  def handle_event("none-btn-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    no_lang_isChecked = not socket.assigns.no_lang_isChecked
    other_lang_isChecked = if no_lang_isChecked, do: false, else: socket.assigns.other_lang_isChecked
    unreachable_isChecked = if no_lang_isChecked, do: false, else: socket.assigns.unreachable_isChecked
    langs = if no_lang_isChecked, do: @default_lang_map, else: socket.assigns.langs

    {:noreply,
     assign(socket,
       other_lang_isChecked: other_lang_isChecked,
       no_lang_isChecked: no_lang_isChecked,
       unreachable_isChecked: unreachable_isChecked,
       langs: langs
     )}
  end

  def handle_event("unreachable-btn-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    unreachable_isChecked = not socket.assigns.unreachable_isChecked
    other_lang_isChecked = if unreachable_isChecked, do: false, else: socket.assigns.other_lang_isChecked
    no_lang_isChecked = if unreachable_isChecked, do: false, else: socket.assigns.no_lang_isChecked
    langs = if unreachable_isChecked, do: @default_lang_map, else: socket.assigns.langs

    {:noreply,
     assign(socket,
       other_lang_isChecked: other_lang_isChecked,
       no_lang_isChecked: no_lang_isChecked,
       unreachable_isChecked: unreachable_isChecked,
       langs: langs
     )}
  end

  def handle_event("no-ppl-btn-event", %{"value" => other_text}, socket) do
    socket = clear_flash(socket)
    no_people_isChecked = not socket.assigns.no_people_isChecked
    ppl = if no_people_isChecked, do: @default_ethnicity_map, else: socket.assigns.langs

    {:noreply,
     assign(socket,
       no_people_isChecked: no_people_isChecked,
       ppl: ppl
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

    no_lang_isChecked = socket.assigns.no_lang_isChecked
    unreachable_isChecked = socket.assigns.unreachable_isChecked
    res = if no_lang_isChecked, do: "none", else: res
    res = if unreachable_isChecked, do: "unreachable", else: res

    other_lang_isChecked = socket.assigns.other_lang_isChecked
    res = if other_lang_isChecked && res != "", do: res <> "|" <> socket.assigns.text_value, else: res
    res = if other_lang_isChecked && res == "", do: socket.assigns.text_value, else: res

    ppl = socket.assigns.ppl

    ppl_res =
      ppl
      |> Enum.filter(fn {_, %{is_checked: checked_value}} ->
        checked_value
      end)
      |> Enum.map(fn {x, _} -> x end)
      |> Enum.sort()
      |> Enum.join("/")
    ppl_res = if socket.assigns.no_people_isChecked, do: "none", else: ppl_res

    res = if res != "", do: res <> "[]" <> ppl_res

    user_id = socket.assigns.current_user.id

    case res do
      "" ->
        {:noreply, put_flash(socket, :error, "Language is not chosen")}

      lang ->
        id

        |> LinkLangClassifier.Links.classify(lang)
        result = get_next_link(user_id)


        result = get_existing_video(user_id)

        new_links_count = count_progress(user_id)
        new_payment_count = count_payment(user_id)

        Process.send_after(self(), {:time_up, true}, @submit_button_wait_ms)

        {:noreply, assign(socket, link: result, langs: @default_lang_map, ppl: @default_ethnicity_map, payment_count: new_payment_count, links_count: new_links_count, other_lang_isChecked: false, no_lang_isChecked: false, unreachable_isChecked: false, text_value: "", no_people_isChecked: false, time_up: false)}
    end
  end

  @impl true
  def handle_event("btn-event", %{"lang" => lang}, socket) do
    socket = clear_flash(socket)

    langs = socket.assigns.langs
    params = Map.get(langs, lang)

    value_checked = Map.get(params, :is_checked)
    no_lang_isChecked = if value_checked, do: socket.assigns.no_lang_isChecked, else: false
    unreachable_isChecked = if value_checked, do: socket.assigns.unreachable_isChecked, else: false

    new_params = Map.put(params, :is_checked, !value_checked)

    new_langs = Map.put(langs, lang, new_params)

    {:noreply, assign(socket, langs: new_langs, no_lang_isChecked: no_lang_isChecked, unreachable_isChecked: unreachable_isChecked)}
  end

end
