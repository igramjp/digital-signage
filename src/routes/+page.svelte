<script lang="ts">
  import "../app.css";
  import { getCurrentTime, SIGNAGE_VERSION } from "$lib";

  let now = getCurrentTime();
</script>

<h1>Hello, Digital Signage!</h1>
<p>This is a static site powered by SvelteKit.</p>

<p>現在時刻: {now}</p>
<p>バージョン: {SIGNAGE_VERSION}</p>
