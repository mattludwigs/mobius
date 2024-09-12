# credo:disable-for-this-file
defmodule Mobius.Asciichart do
  @moduledoc false

  # ASCII chart generation.

  # This module was taking from [sndnv's elixir asciichart package](https://github.com/sndnv/asciichart)
  # and modified to meet the needs of this project.

  # Ported to Elixir from [https://github.com/kroitor/asciichart](https://github.com/kroitor/asciichart)

  @doc ~S"""
  Generates a chart for the specified list of numbers.

  Optionally, the following settings can be provided:
    * :offset - the number of characters to set as the chart's offset (left)
    * :height - adjusts the height of the chart
    * :padding - one or more characters to use for the label's padding (left)

  ## Examples

      iex> Asciichart.plot([1, 2, 3, 3, 2, 1])
      {:ok, "3.00 ┤ ╭─╮ \n2.00 ┤╭╯ ╰╮\n1.00 ┼╯   ╰\n"}

      # should render as

      3.00 ┤ ╭─╮
      2.00 ┤╭╯ ╰╮
      1.00 ┼╯   ╰

      iex> Asciichart.plot([1, 2, 6, 6, 2, 1], height: 2)
      {:ok, "6.00 ┤ ╭─╮ \n3.50 ┤ │ │ \n1.00 ┼─╯ ╰─\n"}

      # should render as

      6.00 ┤ ╭─╮
      3.50 ┤ │ │
      1.00 ┼─╯ ╰─

      iex> Asciichart.plot([1, 2, 5, 5, 4, 3, 2, 100, 0], height: 3, offset: 10, padding: "__")
      {:ok, "100.00     ┤      ╭╮\n_50.00     ┤      ││\n__0.00     ┼──────╯╰\n"}

      # should render as

      100.00    ┤      ╭╮
      _50.00    ┤      ││
      __0.00    ┼──────╯╰


      # Rendering of empty charts is not supported

      iex> Asciichart.plot([])
      {:error, "No data"}
  """
  def plot(series, cfg \\ %{}) do
    case series do
      [] ->
        {:error, "No data"}

      [_ | _] ->
        minimum = Enum.min(series)
        maximum = Enum.max(series)

        interval = abs(maximum - minimum)
        offset = cfg[:offset] || 3
        height = if cfg[:height], do: cfg[:height] - 1, else: interval
        padding = cfg[:padding] || " "
        ratio = if interval == 0, do: 1, else: height / interval
        min2 = safe_floor(minimum * ratio)
        max2 = safe_ceil(maximum * ratio)

        intmin2 = trunc(min2)
        intmax2 = trunc(max2)

        rows = abs(intmax2 - intmin2)
        rows_denom = max(1, rows)

        max_label_size =
          (maximum / 1)
          |> Float.round(2)
          |> :erlang.float_to_binary(decimals: 2)
          |> String.length()

        min_label_size =
          (minimum / 1)
          |> Float.round(2)
          |> :erlang.float_to_binary(decimals: 2)
          |> String.length()

        label_size = max(min_label_size, max_label_size)

        row_values =
          intmin2..intmax2
          |> Enum.map(fn y ->
            (maximum - (y - intmin2) * interval / rows_denom)
            |> Float.round(2)
          end)
          |> Enum.with_index()

        {_, y_inital} =
          Enum.min_by(row_values, fn {val, _} -> {abs(Enum.at(series, 0) - val), abs(val)} end)

        zero_axis_row = Enum.find_value(row_values, fn {val, i} -> if(val == 0, do: i) end)

        # axis and labels
        labels =
          Enum.map(row_values, fn {val, y} ->
            label =
              val
              |> :erlang.float_to_binary(decimals: 2)
              |> String.pad_leading(label_size, padding)
              |> String.pad_trailing(offset, " ")

            axis =
              cond do
                val == 0 -> "┼"
                y == y_inital -> "┼"
                true -> "┤"
              end

            "#{label} #{axis}"
          end)

        data =
          series
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.with_index()
          |> Enum.flat_map(fn {[a, b], x} ->
            {_, y0} = Enum.min_by(row_values, fn {val, _} -> {abs(a - val), abs(val)} end)
            {_, y1} = Enum.min_by(row_values, fn {val, _} -> {abs(b - val), abs(val)} end)

            cond do
              y0 == y1 -> [{{y0, x}, "─"}]
              y0 < y1 -> [{{y0, x}, "╮"}, connections(y0, y1, x), {{y1, x}, "╰"}]
              y0 > y1 -> [{{y1, x}, "╭"}, connections(y0, y1, x), {{y0, x}, "╯"}]
            end
            |> List.flatten()
          end)
          |> Map.new()

        result =
          for {label, y} <- Enum.with_index(labels) do
            row =
              for x <- 0..(length(series) - 2), into: "" do
                empty = if y == zero_axis_row, do: "┄", else: " "
                Map.get(data, {y, x}, empty)
              end

            "#{label}#{row}"
          end
          |> Enum.join("\n")

        {:ok, result <> "\n"}
    end
  end

  defp connections(y0, y1, x) when abs(y0 - y1) > 1 do
    (min(y0, y1) + 1)..max(y0, y1)
    |> Enum.drop(-1)
    |> Enum.map(fn y -> {{y, x}, "│"} end)
  end

  defp connections(_, _, _), do: []

  defp safe_floor(n) when is_integer(n) do
    n
  end

  defp safe_floor(n) when is_float(n) do
    Float.floor(n)
  end

  defp safe_ceil(n) when is_integer(n) do
    n
  end

  defp safe_ceil(n) when is_float(n) do
    Float.ceil(n)
  end

  # Ported loosely to Elixir from [https://observablehq.com/@chrispahm/hello-asciichart](https://observablehq.com/@chrispahm/hello-asciichart)
  def plot_with_x_axis(y_series, x_series, cfg \\ %{})

  def plot_with_x_axis(y_series, nil, cfg) do
    x_series = for {_, i} <- Enum.with_index(y_series), do: i
    plot_with_x_axis(y_series, x_series, cfg)
  end

  def plot_with_x_axis(y_series, x_series, cfg) do
    case plot(y_series, cfg) do
      {:ok, plot} ->
        first_line = plot |> String.splitter("\n") |> Enum.at(0)

        full_width = String.length(first_line)
        legend_first_line = first_line |> String.splitter(["┤", "┼╮", "┼"]) |> Enum.at(0)
        reserved_y_legend_width = String.length(legend_first_line) + 1
        width_x_axis = full_width - reserved_y_legend_width

        longest_x_label =
          x_series
          |> Enum.map(fn item -> item |> to_shortest_string() |> String.length() end)
          |> Enum.max()

        max_decimals =
          Keyword.get_lazy(cfg, :decimals, fn ->
            x_series
            |> Enum.map(fn
              float when is_float(float) ->
                float
                |> to_shortest_string()
                |> String.split(".")
                |> List.last()
                |> String.length()

              _ ->
                0
            end)
            |> Enum.max()
          end)

        max_no_x_labels = div(width_x_axis, longest_x_label + 2) + 1

        first_x_value = List.first(x_series)
        last_x_value = List.last(x_series)
        tick_size = div(width_x_axis, max_no_x_labels - 1)

        ticks =
          Stream.repeatedly(fn -> "┬" end)
          |> Enum.take(max_no_x_labels)
          |> Enum.intersperse(String.duplicate("─", tick_size - 1))
          |> Enum.into("")
          |> String.pad_trailing(width_x_axis, "─")

        slope = (last_x_value - first_x_value) / width_x_axis

        labels =
          0
          |> Stream.iterate(&(&1 + tick_size))
          |> Stream.map(fn x ->
            Float.round(first_x_value + slope * x, max_decimals)
          end)
          |> Enum.take(max_no_x_labels)

        legend_padding = String.duplicate(" ", reserved_y_legend_width - 1)

        tick_labels =
          labels
          |> Enum.reduce(legend_padding <> " ", fn label, acc ->
            label = to_shortest_string(label)
            relative_to_tick = floor(String.length(label) / 2)

            prev =
              case relative_to_tick do
                0 ->
                  acc

                x when x > 0 ->
                  {prev, _} = String.split_at(acc, -1 * x)
                  prev
              end

            label = String.pad_trailing(label, tick_size + relative_to_tick, " ")
            prev <> label
          end)
          |> String.trim_trailing()
          |> String.pad_trailing(reserved_y_legend_width + width_x_axis, " ")

        tick_string = legend_padding <> "└" <> ticks

        plot = "#{plot}#{tick_string}\n#{tick_labels}\n"

        {:ok, plot}

      error ->
        error
    end
  end

  defp to_shortest_string(float) when is_float(float) do
    if Float.floor(float) == float do
      float |> trunc() |> Integer.to_string()
    else
      Float.to_string(float)
    end
  end

  defp to_shortest_string(int) when is_integer(int), do: Integer.to_string(int)
end
