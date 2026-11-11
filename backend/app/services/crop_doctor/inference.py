import io
from PIL import Image
import torch
from transformers import AutoImageProcessor, AutoModelForImageClassification

# Your model from Hugging Face
MODEL_ID = "neghani/plantvillage-mobilenetv2"

print("Loading model... Please wait.")
processor = AutoImageProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageClassification.from_pretrained(MODEL_ID)
model.eval()
print("Model loaded successfully!")


def get_prediction(image_bytes: bytes):
  # Open the image uploaded by the user
  image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

  # Prepare the image for the model
  inputs = processor(images=image, return_tensors="pt")

  # Run prediction
  with torch.no_grad():
    outputs = model(**inputs)
    probs = torch.nn.functional.softmax(outputs.logits, dim=-1)

  confidence, predicted_idx = torch.max(probs, dim=-1)
  label = model.config.id2label[predicted_idx.item()]

  return {"label": label, "confidence": round(confidence.item() * 100, 2)}