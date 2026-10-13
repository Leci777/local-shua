/* 本地刷管理页逻辑。同源 fetch /api/*，无 CORS 问题；无框架、无构建。 */
(function () {
  "use strict";

  var pairCodeEl = document.getElementById("pair-code");
  var versionEl = document.getElementById("version");
  var rowsEl = document.getElementById("folder-rows");
  var statusbarEl = document.getElementById("statusbar");
  var addForm = document.getElementById("add-folder-form");
  var addError = document.getElementById("add-error");

  // 正在轮询扫描进度的 folderId，避免重复触发
  var polling = {};

  function api(path, options) {
    return fetch(path, options).then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: res.ok, status: res.status, body: body };
      });
    });
  }

  function showError(text) {
    addError.textContent = text;
    addError.hidden = false;
  }
  function hideError() {
    addError.hidden = true;
  }

  function formatTime(iso) {
    if (!iso) return "没扫过";
    var d = new Date(iso);
    if (isNaN(d)) return "没扫过";
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) +
      " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  /* ===== 服务信息 + 配对码 ===== */
  function loadInfo() {
    api("/api/server/info").then(function (r) {
      if (!r.ok) return;
      versionEl.textContent = "v" + (r.body.version || "1.0.0");
      pairCodeEl.textContent = "······";
      statusbarEl.textContent =
        r.body.serverName + " · 视频 " + r.body.videoCount + " 个 · 文件夹 " +
        r.body.folderCount + " 个（启用 " + r.body.enabledFolderCount + " 个）";
    });
  }

  // 重新生成配对码：调公开端点（管理页与托盘同权，架构 §2.5 口径），拿到新码直接刷新显示
  document.getElementById("regen-code").addEventListener("click", function () {
    fetch("/api/pairing/regenerate", { method: "POST" })
      .then(function (res) { return res.json(); })
      .then(function (body) {
        pairCodeEl.textContent = body.code || "获取失败";
      })
      .catch(function () {
        pairCodeEl.textContent = "获取失败，去托盘菜单试试";
      });
  });

  /* ===== 文件夹列表 ===== */
  function loadFolders() {
    api("/api/folders").then(function (r) {
      if (!r.ok) {
        rowsEl.innerHTML = '<tr><td colspan="6" class="empty">加载失败：' +
          escapeHtml(r.body.message || "未知错误") + "</td></tr>";
        return;
      }
      renderFolders(r.body);
    });
  }

  function renderFolders(folders) {
    if (!folders.length) {
      rowsEl.innerHTML = '<tr><td colspan="6" class="empty">还没添加文件夹。加一个，然后点「扫描」。</td></tr>';
      return;
    }
    rowsEl.innerHTML = "";
    folders.forEach(function (f) {
      var tr = document.createElement("tr");
      if (!f.enabled) tr.className = "row-disabled";

      var tdSwitch = document.createElement("td");
      var label = document.createElement("label");
      label.className = "switch";
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = f.enabled;
      cb.addEventListener("change", function () { toggleFolder(f.id, cb.checked); });
      var slider = document.createElement("span");
      slider.className = "slider";
      label.appendChild(cb);
      label.appendChild(slider);
      tdSwitch.appendChild(label);

      var tdName = document.createElement("td");
      tdName.textContent = f.name;
      if (f.unplayableCount > 0) {
        var badge = document.createElement("span");
        badge.className = "badge-unplayable";
        badge.textContent = f.unplayableCount + " 个可能无法播放";
        badge.title = "ffprobe 读不出这些文件的信息，大多是格式太偏或文件损坏";
        tdName.appendChild(badge);
      }

      var tdPath = document.createElement("td");
      tdPath.className = "path";
      tdPath.textContent = f.path;

      var tdCount = document.createElement("td");
      tdCount.textContent = f.videoCount + " 个";

      var tdScan = document.createElement("td");
      tdScan.textContent = formatTime(f.lastScanAt);
      var scanBadge = document.createElement("span");
      scanBadge.className = "badge-scanning";
      scanBadge.id = "scan-badge-" + f.id;
      scanBadge.hidden = true;
      tdScan.appendChild(scanBadge);

      var tdActions = document.createElement("td");
      tdActions.className = "actions";
      var scanBtn = document.createElement("button");
      scanBtn.className = "btn-small";
      scanBtn.textContent = "扫描";
      scanBtn.addEventListener("click", function () { startScan(f.id, scanBtn, scanBadge); });
      var delBtn = document.createElement("button");
      delBtn.className = "btn-small danger";
      delBtn.textContent = "删除";
      delBtn.addEventListener("click", function () { removeFolder(f.id, f.name); });
      tdActions.appendChild(scanBtn);
      tdActions.appendChild(delBtn);

      tr.appendChild(tdSwitch);
      tr.appendChild(tdName);
      tr.appendChild(tdPath);
      tr.appendChild(tdCount);
      tr.appendChild(tdScan);
      tr.appendChild(tdActions);
      rowsEl.appendChild(tr);
    });
  }

  /* ===== 操作 ===== */
  addForm.addEventListener("submit", function (e) {
    e.preventDefault();
    hideError();
    var path = document.getElementById("folder-path").value.trim();
    var name = document.getElementById("folder-name").value.trim();
    api("/api/folders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: path, name: name || null })
    }).then(function (r) {
      if (r.ok) {
        document.getElementById("folder-path").value = "";
        document.getElementById("folder-name").value = "";
        loadFolders();
        loadInfo();
      } else {
        showError(r.body.message || "添加失败");
      }
    });
  });

  function toggleFolder(id, enabled) {
    api("/api/folders/" + id + "/enabled", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ enabled: enabled })
    }).then(function () {
      loadFolders();
      loadInfo();
    });
  }

  function removeFolder(id, name) {
    if (!confirm("确定把「" + name + "」取消登记吗？磁盘上的文件不会动。")) return;
    api("/api/folders/" + id, { method: "DELETE" }).then(function () {
      loadFolders();
      loadInfo();
    });
  }

  function startScan(id, btn, badge) {
    if (polling[id]) return;
    api("/api/folders/" + id + "/scan", { method: "POST" }).then(function (r) {
      if (r.status === 409) {
        badge.hidden = false;
        badge.textContent = "正在扫描中…";
        pollScan(id, badge);
        return;
      }
      if (!r.ok) return;
      badge.hidden = false;
      badge.textContent = "扫描中…";
      btn.disabled = true;
      pollScan(id, badge, btn);
    });
  }

  function pollScan(id, badge, btn) {
    polling[id] = true;
    var timer = setInterval(function () {
      api("/api/folders/" + id + "/scan/latest").then(function (r) {
        if (!r.ok) return;
        var s = r.body;
        if (s.status === "running" || s.status === "never") {
          badge.textContent = "扫描中…";
          return;
        }
        clearInterval(timer);
        delete polling[id];
        badge.hidden = true;
        if (btn) btn.disabled = false;
        if (s.status === "failed") {
          badge.hidden = false;
          badge.textContent = "扫描失败";
        }
        loadFolders();
        loadInfo();
      });
    }, 1000);
  }

  /* ===== 启动 ===== */
  loadInfo();
  loadFolders();
})();
