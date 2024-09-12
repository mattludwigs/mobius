defmodule Mobius.ExportsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mobius.Exports
  alias Mobius.Exports.MobiusBinaryFormat

  @tag :tmp_dir
  test "export and parse Mobius Binary Format to binary", %{tmp_dir: tmp_dir} do
    metrics = [
      Telemetry.Metrics.last_value("make.mbf.value"),
      Telemetry.Metrics.last_value("make.another.value")
    ]

    args =
      tmp_dir
      |> make_args()
      |> Keyword.merge(metrics: metrics, mobius_instance: :export_mbf)

    {:ok, _} = start_supervised({Mobius, args})
    execute_telemetry([:make, :mbf], %{value: 100})
    execute_telemetry([:make, :another], %{value: 100})

    # make sure there's time for the scrapper
    Process.sleep(1_000)

    mbf = Exports.mbf(mobius_instance: :export_mbf)

    assert {:ok, metrics} = Exports.parse_mbf(mbf)

    assert is_list(metrics)
    assert Enum.all?(metrics, fn m -> m.name in ["make.mbf.value", "make.another.value"] end)
  end

  @tag :tmp_dir
  test "export version 1 Mobius Binary Format to file", %{tmp_dir: tmp_dir} do
    {:ok, _} = start_supervised({Mobius, make_args(tmp_dir)})
    expected_bin = MobiusBinaryFormat.to_iodata([]) |> IO.iodata_to_binary()

    {:ok, file} = Exports.mbf(out_dir: tmp_dir)

    assert File.read!(file) == expected_bin
  end

  @tag :tmp_dir
  test "plot", %{tmp_dir: tmp_dir} do
    metrics = [
      Telemetry.Metrics.last_value("some.value")
    ]

    args =
      tmp_dir
      |> make_args()
      |> Keyword.merge(metrics: metrics)

    {:ok, _} = start_supervised({Mobius, args})

    # TODO inject via history instead of using up 10s per test
    Stream.interval(1000)
    |> Stream.map(fn val -> execute_telemetry([:some], %{value: val}) end)
    |> Enum.take(10)

    Process.sleep(1000)

    output =
      capture_io(fn ->
        assert :ok = Exports.plot("some.value", :last_value)
      end)

    # IO.puts(output)

    expected =
      [
        "9.00 ┤        ╭",
        "8.18 ┤       ╭╯",
        "7.36 ┤      ╭╯ ",
        "6.55 ┤      │  ",
        "5.73 ┤     ╭╯  ",
        "4.91 ┤    ╭╯   ",
        "4.09 ┤   ╭╯    ",
        "3.27 ┤  ╭╯     ",
        "2.45 ┤  │      ",
        "1.64 ┤ ╭╯      ",
        "0.82 ┤╭╯       ",
        "0.00 ┼╯┄┄┄┄┄┄┄┄",
        "     └┬───┬───┬",
        "     -9  -5  -1",
        ""
      ]
      |> Enum.join("\n")

    assert output =~ expected
  end

  defp make_args(persistence_dir) do
    [
      metrics: [],
      persistence_dir: persistence_dir
    ]
  end

  defp execute_telemetry(event, measurements) do
    :telemetry.execute(event, measurements, %{})
  end
end
