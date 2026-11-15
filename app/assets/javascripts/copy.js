// "Copier" buttons: data-copy-target names the field whose value they copy (the copy_field helper)

// Without the Clipboard API (plain HTTP, older browsers), select the text and copy it the old way
const copyBySelection = (field) => {
  field.removeAttribute("readonly");
  field.select();
  field.setSelectionRange(0, field.value.length);
  const copied = document.execCommand("copy");
  field.setAttribute("readonly", "");
  field.blur();
  return copied;
};

const showCopied = (button) => {
  const icon = button.querySelector("i");
  icon?.classList.replace("ri-file-copy-line", "ri-check-line");
  button.classList.replace("btn-outline-primary", "btn-success");
  setTimeout(() => {
    icon?.classList.replace("ri-check-line", "ri-file-copy-line");
    button.classList.replace("btn-success", "btn-outline-primary");
  }, 2000);
};

document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy-target]");
  if (!button) return;

  const field = document.getElementById(button.dataset.copyTarget);
  try {
    // Throws at once when the API is missing, so the fallback still runs within the click
    await navigator.clipboard.writeText(field.value);
    showCopied(button);
  } catch {
    if (copyBySelection(field)) showCopied(button);
  }
});
