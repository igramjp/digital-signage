<script lang="ts">
  import "../app.css";
  import { SIGNAGE_VERSION } from "$lib";

  let videoElement: HTMLVideoElement;
  let isPlaying = false;
  let playCount = 0;
  let currentStep = 1; // 現在のステップ
  let currentTime = 0; // 現在の再生時間（秒）
  let duration = 0; // 動画の総時間（秒）
  let showDataPanel = true; // データパネルの表示/非表示

  // 再生開始のトリガー
  function handlePlay(event: Event): void {
    console.log("動画再生開始:", event);
    isPlaying = true;
    playCount++;
    // ここに再生開始時の処理を書く
  }

  // 再生終了のトリガー
  function handleEnded(event: Event): void {
    console.log("動画再生終了:", event);
    console.log("終了したステップ:", currentStep);
    isPlaying = false;

    // 現在のステップに応じた処理例
    if (currentStep < 5) {
      // 自動で次のステップに進む場合
      // switchVideo(currentStep + 1);
    } else {
      // Step5の場合、最初に戻る
      // switchVideo(1);
    }
  }

  // 一時停止のトリガー
  function handlePause(event: Event): void {
    console.log("動画一時停止:", event);
    isPlaying = false;
  }

  // 時間更新のトリガー
  function handleTimeUpdate(event: Event): void {
    if (videoElement) {
      currentTime = videoElement.currentTime;
      duration = videoElement.duration || 0;
    }
  }

  // 動画メタデータ読み込み完了
  function handleLoadedMetadata(event: Event): void {
    if (videoElement) {
      duration = videoElement.duration || 0;
    }
  }

  // 時間を分:秒形式にフォーマット
  function formatTime(seconds: number): string {
    if (isNaN(seconds)) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  }

  // 動画の進行度を計算（0-100%、小数点以下第四位まで）
  $: progressPercentage =
    duration > 0 ? parseFloat(((currentTime / duration) * 100).toFixed(4)) : 0;

  // データパネルの表示切り替え
  function toggleDataPanel(): void {
    showDataPanel = !showDataPanel;
  }

  // 動画を手動で再生
  function playVideo(): void {
    if (videoElement) {
      videoElement.play();
    }
  }

  // 動画を手動で停止
  function pauseVideo(): void {
    if (videoElement) {
      videoElement.pause();
    }
  }

  // 動画を手動で停止
  function stopVideo(): void {
    if (videoElement) {
      videoElement.pause();
      videoElement.currentTime = 0;
    }
  }

  // 動画を切り替える
  function switchVideo(step: number): void {
    if (videoElement) {
      videoElement.src = `/videos/step${step}.mp4`;
      currentStep = step;

      // 動画を読み込んで自動再生
      videoElement.load();
      videoElement.play();
    }
  }
</script>

<div class="stage">
  <!-- svelte-ignore a11y-media-has-caption -->
  <video
    bind:this={videoElement}
    on:play={handlePlay}
    on:ended={handleEnded}
    on:pause={handlePause}
    on:timeupdate={handleTimeUpdate}
    on:loadedmetadata={handleLoadedMetadata}
    class="main-movie"
  >
    <source src="/videos/step1.mp4" type="video/mp4" />
    <!-- static/videos/ フォルダに動画ファイルを配置してください -->
    お使いのブラウザは動画タグをサポートしていません。
  </video>

  {#if showDataPanel}
    <div class="data-panel">
      <div id="content-info" class="data-panel-item step-{currentStep}">
        <p>コンテンツ</p>
        <p>STEP {currentStep}</p>
      </div>
      <div
        id="playback-status"
        class="data-panel-item {isPlaying
          ? 'playing'
          : currentTime > 0 && currentTime < duration
            ? 'paused'
            : 'stopped'}"
      >
        <p>再生状態</p>
        <p>
          {isPlaying
            ? "再生中"
            : currentTime > 0 && currentTime < duration
              ? "一時停止"
              : "停止中"}
        </p>
      </div>
      <div
        id="elapsed-time"
        class="data-panel-item"
        style="--progress: {progressPercentage}%"
      >
        <p>経過時間</p>
        <p>{formatTime(currentTime)}</p>
      </div>
      <div id="total-duration" class="data-panel-item">
        <p>総再生時間</p>
        <p>{formatTime(duration)}</p>
      </div>
    </div>
  {/if}

  <div class="control-panel">
    <div class="movie-control">
      <button id="play-btn" on:click={playVideo} class:active={isPlaying}
        >再生</button
      >
      <button
        id="pause-btn"
        on:click={pauseVideo}
        class:active={!isPlaying && currentTime > 0 && currentTime < duration}
        >一時停止</button
      >
      <button
        id="stop-btn"
        on:click={stopVideo}
        class:active={!isPlaying &&
          (currentTime === 0 || currentTime >= duration)}>停止</button
      >
    </div>

    <div class="step-control">
      <button on:click={() => switchVideo(1)} class:active={currentStep === 1}
        >STEP 1</button
      >
      <button on:click={() => switchVideo(2)} class:active={currentStep === 2}
        >STEP 2</button
      >
      <button on:click={() => switchVideo(3)} class:active={currentStep === 3}
        >STEP 3</button
      >
      <button on:click={() => switchVideo(4)} class:active={currentStep === 4}
        >STEP 4</button
      >
      <button on:click={() => switchVideo(5)} class:active={currentStep === 5}
        >STEP 5</button
      >
    </div>

    <div
      class="logo"
      on:click={toggleDataPanel}
      on:keydown={(e) => e.key === "Enter" && toggleDataPanel()}
      role="button"
      tabindex="0"
    >
      <img src="/images/logo.webp" alt="logo" />
    </div>
  </div>
</div>
