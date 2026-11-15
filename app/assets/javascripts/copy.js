// "Copier" buttons: data-copy-target names the field whose value they copy (AdminHelper#copy_field)
document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-copy-target]");
  if (!button) return;

  const field = document.getElementById(button.dataset.copyTarget);
  const icon = button.querySelector("i");
  const copied = () => {
    icon?.classList.replace("ri-file-copy-line", "ri-check-line");
    setTimeout(() => icon?.classList.replace("ri-check-line", "ri-file-copy-line"), 2000);
  };
  if (navigator.clipboard) {
    navigator.clipboard.writeText(field.value).then(copied, () => field.select());
  } else {
    field.select();
  }
});
