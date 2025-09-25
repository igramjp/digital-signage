<script lang="ts">
  import "../../app.css";
  import { onMount } from "svelte";

  let progress = 0;
  let status = "準備中...";
  let closable = true; // 常にクリックで閉じられる

  async function closeSplash() {
    try {
      const { getCurrentWindow } = await import("@tauri-apps/api/window");
      const w = getCurrentWindow();
      await w.close();
    } catch (_) {
      // 非Tauri環境などではブラウザ挙動にフォールバック
      try {
        window.close();
      } catch (_) {
        // 何もしない
      }
    }
  }

  onMount(() => {
    (async () => {
      try {
        const { listen } = await import("@tauri-apps/api/event");
        const unlisten1 = await listen<{ progress: number; status: string }>(
          "preload_progress",
          (e) => {
            const p = e.payload?.progress ?? 0;
            const s = e.payload?.status ?? "";
            // console.log(`Splash画面: 進捗更新受信 - ${p}% - ${s}`);
            progress = p;
            if (s) status = s;
          },
        );
        const unlisten2 = await listen("preload_done", async () => {
          await closeSplash();
        });

        return () => {
          unlisten1();
          unlisten2();
        };
      } catch (_) {
        // 非Tauri環境やリスナー登録失敗時は静かに無視
      }
    })();
  });
</script>

<div
  class="splash-wrap"
  class:ready={closable}
  role="button"
  tabindex="0"
  on:click={() => {
    if (closable) closeSplash();
  }}
  on:keydown={(e) => {
    if (closable && (e.key === "Enter" || e.key === " ")) {
      e.preventDefault();
      closeSplash();
    }
  }}
  title={closable ? "閉じる" : "読み込み中"}
>
  <div class="bar" style={`--w: ${progress}%`}><i></i></div>
  <div class="label"><span class="percent">{progress}%</span></div>
</div>

<style>
  .splash-wrap {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100vh;
    padding: 24px;
    box-sizing: border-box;
    background: #0b0b0b;
    color: #fff;
    gap: 16px;
    /* macOSウィンドウのデコレーションを考慮した調整 */
    padding-top: 40px; /* タイトルバーの高さ分を追加 */
  }
  .splash-wrap.ready {
    cursor: pointer;
  }
  .bar {
    width: 90%;
    max-width: 640px;
    height: 10px;
    background: #2a2a2a;
    border-radius: 999px;
    overflow: hidden;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.06);
  }
  .bar > i {
    display: block;
    height: 100%;
    width: var(--w, 0%);
    background: linear-gradient(90deg, #1db954, #4caf50);
    transition: width 120ms ease-out;
  }
  .label {
    font-size: 14px;
    opacity: 0.85;
  }
  .percent {
    font-variant-numeric: tabular-nums;
  }
</style>
