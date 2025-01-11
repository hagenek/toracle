window.handleImageSelect = function (input, hookId) {
  console.log("handleImageSelect called with hookId:", hookId);
  const file = input.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = function (e) {
      console.log("File read complete");
      const previewContainer = document.getElementById("preview-container");
      const previewImage = document.getElementById("preview-image");

      // Use querySelector to find the element with phx-hook attribute
      const hookElement = document.querySelector(`[phx-hook="ImageHook"]`);

      if (!hookElement) {
        console.error("Hook element not found!");
        return;
      }

      if (previewImage && previewContainer) {
        previewImage.src = e.target.result;
        previewContainer.classList.remove("hidden");
      }

      // Create and dispatch the event
      const event = new CustomEvent("imageSelected", {
        detail: { image: e.target.result },
      });

      console.log("Dispatching event to hook element:", hookElement);
      hookElement.dispatchEvent(event);
    };
    reader.readAsDataURL(file);
  }
};
