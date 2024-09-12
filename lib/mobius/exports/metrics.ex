defmodule Mobius.Exports.Metrics do
  @moduledoc false

  # Module for exporting metrics

  alias Mobius.{Exports, Scraper, Summary}

  @doc """
  Export metrics
  """
  @spec export(binary(), Mobius.metric_type(), map(), [Exports.export_opt()]) :: [Mobius.metric()]
  def export(metric_name, type, tags, opts \\ []) do
    mobius_instance = opts[:mobius_instance] || :mobius

    start_t = System.monotonic_time()
    prefix = [:mobius, :export, :metrics]

    scraper_opts = query_opts(opts)

    # Notify telemetry we are starting query
    :telemetry.execute(prefix ++ [:start], %{system_time: System.system_time()}, %{
      mobius_instance: mobius_instance,
      metric_name: metric_name,
      tags: tags,
      type: type,
      opts: scraper_opts
    })

    rows =
      Scraper.all(mobius_instance, scraper_opts)
      |> filter_metrics_for_metric(metric_name, type, tags)

    # Notify telemetry we finished query
    duration = System.monotonic_time() - start_t

    :telemetry.execute(prefix ++ [:stop], %{duration: duration}, %{
      mobius_instance: mobius_instance,
      metric_name: metric_name,
      tags: tags,
      opts: scraper_opts
    })

    rows
  end

  defp filter_metrics_for_metric(metrics, metric_name, :summary, tags) do
    do_filter_metrics_for_metric(metrics, metric_name, :summary, tags)
    |> Enum.map(fn metric ->
      %{metric | value: metric.value |> Summary.calculate()}
    end)
  end

  defp filter_metrics_for_metric(metrics, metric_name, {:summary, summary_metric}, tags) do
    do_filter_metrics_for_metric(metrics, metric_name, :summary, tags)
    |> Enum.map(fn metric ->
      %{metric | value: metric.value |> Summary.calculate() |> Map.get(summary_metric)}
    end)
  end

  defp filter_metrics_for_metric(metrics, metric_name, type, tags) do
    do_filter_metrics_for_metric(metrics, metric_name, type, tags)
  end

  defp do_filter_metrics_for_metric(metrics, metric_name, type, tags) do
    Enum.filter(metrics, fn metric ->
      metric_name == metric.name && match?(^tags, metric.tags) && type == metric.type
    end)
  end

  defp query_opts(opts) do
    if opts[:from] do
      Keyword.take(opts, [:from, :to])
    else
      last_ts(opts)
    end
  end

  defp last_ts(opts) do
    now = System.system_time(:second)

    ts =
      case opts[:last] do
        nil ->
          now - 180

        {offset, unit} ->
          now - offset * get_unit_offset(unit)

        offset ->
          now - offset
      end

    [from: ts]
  end

  def get_unit_offset(:second), do: 1
  def get_unit_offset(:minute), do: 60
  def get_unit_offset(:hour), do: 3600
  def get_unit_offset(:day), do: 86400
end
