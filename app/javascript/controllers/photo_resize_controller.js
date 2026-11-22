import { Controller } from "@hotwired/stimulus"

// Shrinks the chosen photo to a centred square before it is uploaded, so profile pictures load quickly.
// If the browser cannot do it, the original file is uploaded and the server checks it (JPG or PNG, 1.5 MB at most).
export default class extends Controller {
  static targets = ["input", "error", "preview"]
  static values = {
    size: { type: Number, default: 600 },
    quality: { type: Number, default: 0.85 },
    typeError: String
  }

  async resize() {
    const input = this.inputTarget
    const file = input.files && input.files[0]
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
    if (!file) return

    if (!["image/jpeg", "image/png"].includes(file.type)) {
      input.value = ""
      this.errorTarget.textContent = this.typeErrorValue
      this.errorTarget.hidden = false
      return
    }

    try {
      const bitmap = await createImageBitmap(file)
      const side = Math.min(bitmap.width, bitmap.height)
      const target = Math.min(this.sizeValue, side)
      const canvas = document.createElement("canvas")
      canvas.width = target
      canvas.height = target
      const context = canvas.getContext("2d")
      context.fillStyle = "#ffffff"
      context.fillRect(0, 0, target, target)
      context.drawImage(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side, 0, 0, target, target)
      bitmap.close()

      const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", this.qualityValue))
      if (!blob) return

      const name = file.name.replace(/\.[^.]+$/, "") + ".jpg"
      const resized = new File([blob], name, { type: "image/jpeg" })
      const transfer = new DataTransfer()
      transfer.items.add(resized)
      input.files = transfer.files
      this.showPreview(resized)
    } catch (error) {
      // The browser could not read the picture: the original file stays selected.
    }
  }

  showPreview(file) {
    if (!this.hasPreviewTarget) return

    const frame = document.createElement("span")
    frame.className = "tphoto tphoto--form"
    const image = document.createElement("img")
    image.className = "tphoto__img"
    image.alt = ""
    image.src = URL.createObjectURL(file)
    frame.appendChild(image)
    this.previewTarget.replaceChildren(frame)
  }
}
