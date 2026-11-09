// The frontend only calls relative /api/* paths. The reverse proxy decides where they go,
// so the same static files work behind NGINX, a cloud load balancer, or a Kubernetes Ingress.
const list = document.getElementById("tasks");
const errorBox = document.getElementById("error");

async function api(path, options = {}) {
  const res = await fetch(path, { headers: { "Content-Type": "application/json" }, ...options });
  if (!res.ok && res.status !== 204) throw new Error(`${options.method || "GET"} ${path} -> ${res.status}`);
  return res.status === 204 ? null : res.json();
}

function showError(err) {
  errorBox.textContent = err.message;
  errorBox.hidden = false;
}

async function refresh() {
  try {
    const [info, tasks] = await Promise.all([api("/api/info"), api("/api/tasks")]);
    document.getElementById("info").textContent =
      `api ${info.version} · host ${info.hostname} · storage ${info.backend}`;
    list.replaceChildren(...tasks.map(render));
    errorBox.hidden = true;
  } catch (err) {
    showError(err);
  }
}

function render(task) {
  const li = document.createElement("li");
  const box = document.createElement("input");
  box.type = "checkbox";
  box.checked = task.done;
  box.addEventListener("change", () =>
    api(`/api/tasks/${task.id}`, { method: "PATCH", body: JSON.stringify({ done: box.checked }) })
      .then(refresh).catch(showError));
  const label = document.createElement("span");
  label.textContent = task.title; // textContent, never innerHTML: titles are user input
  if (task.done) label.className = "done";
  const del = document.createElement("button");
  del.textContent = "Delete";
  del.addEventListener("click", () =>
    api(`/api/tasks/${task.id}`, { method: "DELETE" }).then(refresh).catch(showError));
  li.append(box, label, del);
  return li;
}

document.getElementById("new-task").addEventListener("submit", async (event) => {
  event.preventDefault();
  const input = document.getElementById("title");
  try {
    await api("/api/tasks", { method: "POST", body: JSON.stringify({ title: input.value }) });
    input.value = "";
    refresh();
  } catch (err) {
    showError(err);
  }
});

refresh();
