<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import * as d3 from "d3";

  let chartContainer: HTMLDivElement;
  let chartCreated = false;
  let svg: any;
  let g: any;
  let x: any;
  let y: any;
  let data: any[];

  // onMountで軸と背景を先に表示
  onMount(() => {
    createChartBackground();
  });

  // コンポーネントが破棄される時にチャートをクリア
  onDestroy(() => {
    if (chartContainer) {
      chartContainer.innerHTML = "";
    }
    chartCreated = false;
  });

  // データアニメーション開始用の関数をエクスポート
  export function rerender() {
    if (!chartCreated) {
      createChartBackground();
    }
    startDataAnimation();
  }

  // データ要素のみをクリア（軸と背景は残す）
  export function clearData() {
    if (!chartCreated || !g) return;

    g.selectAll(".line").remove();
    g.selectAll(".dot").remove();
    g.selectAll(".annot").remove();
    g.selectAll(".annot-group").remove();
  }

  // 軸と背景を作成（アニメーションなし）
  function createChartBackground() {
    if (chartCreated) return;

    // データ型定義
    interface DataPoint {
      t: number;
      v: number;
    }

    // データ
    const xs = [
      0.0, 0.3, 0.6, 0.9, 1.5, 2.0, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5,
    ];
    const ys = [
      -145.0, -136.0, -128.0, -122.0, -115.0, -111.0, -105.5, -101.5, -99.0,
      -97.0, -96.0, -95.0, -95.0, -95.0,
    ];
    data = xs.map((t, i) => ({ t, v: ys[i] }));

    const maxX = 30; // 横軸の最大値

    // SVGサイズ
    const width = 770;
    const height = 385;

    // レイアウト
    const margin = { top: 30, right: 40, bottom: 60, left: 70 };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    // SVG作成
    svg = d3
      .select(chartContainer)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("role", "img")
      .attr("aria-label", "PC鋼材の電位 時間変化グラフ（Step2）");

    g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    // スケール & 軸
    x = d3.scaleLinear().domain([0, maxX]).range([0, innerWidth]);
    y = d3.scaleLinear().domain([-200, 0]).nice().range([innerHeight, 0]);

    const xAxis = d3
      .axisBottom(x)
      .tickValues([0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30])
      .tickFormat(d3.format(".0f") as any);
    const yAxis = d3
      .axisLeft(y)
      .tickValues([-200, -160, -120, -80, -40, 0])
      .tickFormat(d3.format(".0f") as any);

    const xGrid = d3
      .axisBottom(x)
      .tickValues(d3.range(0, maxX + 1, 3))
      .tickSize(-innerHeight)
      .tickSizeOuter(0)
      .tickFormat(null);
    const yGrid = d3
      .axisLeft(y)
      .tickValues([-200, -160, -120, -80, -40, 0])
      .tickSize(-innerWidth)
      .tickSizeOuter(0)
      .tickFormat(null);

    // グリッド
    g.append("g")
      .attr("class", "grid")
      .attr("transform", `translate(0.5,${innerHeight + 0.5})`)
      .call(xGrid as any)
      .selectAll("line")
      .attr("stroke-width", 1);
    g.append("g")
      .attr("class", "grid")
      .attr("transform", `translate(0.5,0.5)`)
      .call(yGrid as any)
      .selectAll("line")
      .attr("stroke-width", 1);

    // 軸
    g.append("g")
      .attr("class", "axis")
      .attr("transform", `translate(0,${innerHeight})`)
      .call(xAxis);
    g.append("g").attr("class", "axis").call(yAxis);

    // 軸ラベル
    g.append("text")
      .attr("class", "label")
      .attr("x", innerWidth / 2)
      .attr("y", innerHeight + 45)
      .attr("text-anchor", "middle")
      .text("測定時間 (分)");
    g.append("text")
      .attr("class", "label")
      .attr("transform", "rotate(-90)")
      .attr("x", -innerHeight / 2)
      .attr("y", -48)
      .attr("text-anchor", "middle")
      .text("PC鋼材の電位 (mV vs SCE)");

    chartCreated = true;
  }

  // データのアニメーションを開始
  function startDataAnimation() {
    if (!chartCreated || !g) return;

    // データ型定義
    interface DataPoint {
      t: number;
      v: number;
    }

    const totalDuration = 14000; // データ範囲(0→lastX)の表示に要する時間
    const startDelay = 0; // 即時開始（ディレイ無し）
    const lastX = d3.max(data, (d: DataPoint) => d.t); // 例: 13.5

    // 既存のデータ要素を削除（再アニメーション用）
    g.selectAll(".line").remove();
    g.selectAll(".dot").remove();
    g.selectAll(".annot").remove();
    g.selectAll("g")
      .filter(function (this: any) {
        return d3.select(this).selectAll(".annot").size() > 0;
      })
      .remove();

    // 折れ線
    const line = d3
      .line<DataPoint>()
      .x((d: DataPoint) => x(d.t))
      .y((d: DataPoint) => y(d.v))
      .curve(d3.curveMonotoneX);

    // 折れ線（アニメーション付き）
    const path = g
      .append("path")
      .datum(data)
      .attr("class", "line")
      .attr("d", line);

    // 線の長さを取得してアニメーション
    const totalLength = path.node()?.getTotalLength() || 0;

    path
      .attr("stroke-dasharray", totalLength + " " + totalLength)
      .attr("stroke-dashoffset", totalLength)
      .transition()
      .delay(startDelay)
      .duration(totalDuration)
      .ease(d3.easeLinear)
      .attr("stroke-dashoffset", 0);

    // 点（各点はその時刻に合わせてフェードイン）
    g.selectAll(".dot")
      .data(data)
      .enter()
      .append("circle")
      .attr("class", "dot")
      .attr("cx", (d: DataPoint) => x(d.t))
      .attr("cy", (d: DataPoint) => y(d.v))
      .attr("r", 3.5)
      .attr("opacity", 0)
      .transition()
      .delay(
        (d: DataPoint) => startDelay + (d.t / (lastX || 1)) * totalDuration,
      )
      .duration(250)
      .attr("opacity", 1);

    // 注釈（13.5秒の位置に縦線＋ラベル）
    const x13_5 = x(13.5);
    const lineGroup = g
      .append("g")
      .attr("class", "annot-group")
      .attr("opacity", 0);

    // 垂直線
    lineGroup
      .append("line")
      .attr("class", "annot")
      .attr("x1", x13_5)
      .attr("x2", x13_5)
      .attr("y1", y(-200))
      .attr("y2", y(-95));

    const labelGroup = lineGroup.append("g");
    labelGroup
      .append("rect")
      .attr("x", x13_5 - 36)
      .attr("y", y(-90) - 22)
      .attr("rx", 4)
      .attr("ry", 4)
      .attr("width", 72)
      .attr("height", 22)
      .attr("fill", "#fff")
      .attr("stroke", "#005bac")
      .attr("stroke-width", 1.5);
    labelGroup
      .append("text")
      .attr("x", x13_5)
      .attr("y", y(-90) - 9.5)
      .attr("text-anchor", "middle")
      .attr("dominant-baseline", "middle")
      .attr("fill", "#005bac")
      .attr("font-size", 13)
      .text("不動態化");

    // 全描画完了のタイミングで注釈を出す
    lineGroup
      .transition()
      .delay(startDelay + totalDuration)
      .duration(300)
      .attr("opacity", 1);
  }
</script>

<div bind:this={chartContainer} class="d3-chart-container"></div>

<style>
  .d3-chart-container {
    width: 100%;
    height: 100%;
  }

  :global(.grid line) {
    stroke: #ccc;
    stroke-opacity: 1;
    shape-rendering: crispEdges;
    vector-effect: non-scaling-stroke;
  }

  /* Ensure axis ticks are visible on white background */
  :global(.axis text) {
    fill: #888;
    font-size: 14px;
  }
  :global(.axis line) {
    stroke: #ccc;
  }

  :global(.axis path) {
    display: none;
  }

  :global(.line) {
    fill: none;
    stroke: var(--color-primary);
    stroke-width: 2.5px;
  }

  :global(.dot) {
    fill: var(--color-secondary);
  }

  :global(.annot) {
    stroke: var(--color-primary);
    stroke-width: 2px;
  }

  :global(.label) {
    font-size: 16px;
    fill: #888;
  }
</style>
