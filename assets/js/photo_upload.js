// Photo upload handling
export const PhotoUpload = {
  mounted() {
    this.handleDrop = (e) => {
      e.preventDefault();
      const files = e.dataTransfer ? e.dataTransfer.files : e.target.files;
      
      if (files.length > 0) {
        const file = files[0];
        if (this.validateFile(file)) {
          this.uploadFile(file);
        }
      }
    };

    this.validateFile = (file) => {
      // Check if file is an image
      if (!file.type.startsWith('image/')) {
        this.showError('Please upload an image file');
        return false;
      }

      // Check file size (10MB max)
      if (file.size > 10 * 1024 * 1024) {
        this.showError('File size must be less than 10MB');
        return false;
      }

      return true;
    };

    this.uploadFile = (file) => {
      const reader = new FileReader();
      
      reader.onload = (e) => {
        // Create preview
        const preview = document.createElement('img');
        preview.src = e.target.result;
        preview.classList.add('preview-image');
        
        // Send to server
        this.pushEvent("process-image", {
          image: e.target.result
        });
      };

      reader.readAsDataURL(file);
    };

    this.showError = (message) => {
      this.pushEvent("show-error", { message });
    };

    // Add event listeners
    const dropZone = this.el.querySelector('.drop-zone');
    const fileInput = this.el.querySelector('input[type="file"]');

    if (dropZone) {
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, (e) => {
          e.preventDefault();
          e.stopPropagation();
        });
      });

      ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
          dropZone.classList.add('border-purple-400');
        });
      });

      ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
          dropZone.classList.remove('border-purple-400');
        });
      });

      dropZone.addEventListener('drop', this.handleDrop);
    }

    if (fileInput) {
      fileInput.addEventListener('change', this.handleDrop);
    }
  },

  destroyed() {
    // Clean up event listeners
    const dropZone = this.el.querySelector('.drop-zone');
    const fileInput = this.el.querySelector('input[type="file"]');

    if (dropZone) {
      dropZone.removeEventListener('drop', this.handleDrop);
    }

    if (fileInput) {
      fileInput.removeEventListener('change', this.handleDrop);
    }
  }
};
