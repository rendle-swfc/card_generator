import os
import io
import sys
import cv2
import numpy as np
from flask import Flask, request, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Load face detector
def load_face_cascade():
    cascade = cv2.CascadeClassifier()
    local_path = 'haarcascade_frontalface_default.xml'
    if os.path.exists(local_path) and cascade.load(local_path):
        return cascade
    sys_path = getattr(cv2.data, 'haarcascades', '') + 'haarcascade_frontalface_default.xml'
    if os.path.exists(sys_path) and cascade.load(sys_path):
        return cascade
    return cascade

face_cascade = load_face_cascade()

def create_face_mask(img_shape, faces):
    mask = np.zeros((img_shape[0], img_shape[1]), dtype=np.float32)
    for (x, y, w, h) in faces:
        center = (int(x + w / 2), int(y + h / 2))
        axes = (int(w * 0.70), int(h * 0.85))
        cv2.ellipse(mask, center, axes, 0, 0, 360, 1.0, -1)
    mask = cv2.GaussianBlur(mask, (101, 101), 0)
    return cv2.merge([mask, mask, mask])

def apply_painterly_effect(img, mode='human', intensity='medium'):
    height, width = img.shape[:2]
    target_width = 800
    aspect_ratio = height / width
    target_height = int(target_width * aspect_ratio)
    img_resized = cv2.resize(img, (target_width, target_height), interpolation=cv2.INTER_CUBIC)

    # 1. Bypass mode: Skip style processing entirely
    if mode == 'bypass':
        return img_resized

    # Configure dynamic stroke size based on chosen intensity
    if intensity == 'subtle':
        size = 2
        dyn_ratio = 4
        sigma = 25
    elif intensity == 'heavy':
        size = 5
        dyn_ratio = 8
        sigma = 60
    else:  # medium
        size = 3
        dyn_ratio = 6
        sigma = 40

    # 2. Base Painterly Pass (Scalable oil paint effect)
    smooth = cv2.bilateralFilter(img_resized, d=7, sigmaColor=sigma, sigmaSpace=sigma)
    oil_painted = cv2.xphoto.oilPainting(smooth, size=size, dynRatio=dyn_ratio)

    # 3. High-Pass Detail Map
    gaussian = cv2.GaussianBlur(img_resized, (0, 0), 2)
    high_pass = cv2.addWeighted(img_resized, 1.4, gaussian, -0.4, 0)

    if mode == 'armor':
        gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, threshold1=50, threshold2=150)
        edges_dilated = cv2.dilate(edges, np.ones((3, 3), np.uint8), iterations=1)
        edge_mask = cv2.GaussianBlur(edges_dilated.astype(np.float32) / 255.0, (11, 11), 0)
        edge_mask_3ch = cv2.merge([edge_mask, edge_mask, edge_mask])

        armor_blended = (high_pass * 0.80 + oil_painted * 0.20)
        final_art = (oil_painted * (1.0 - edge_mask_3ch) + armor_blended * edge_mask_3ch).astype(np.uint8)

    elif mode == 'full_paint':
        final_art = cv2.addWeighted(oil_painted, 0.70, high_pass, 0.30, 0)

    else:  # human
        faces = []
        if not face_cascade.empty():
            gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(40, 40))

        if len(faces) > 0:
            face_mask = create_face_mask(img_resized.shape, faces)
            face_blended = (high_pass * 0.85 + oil_painted * 0.15)
            final_art = (oil_painted * (1.0 - face_mask) + face_blended * face_mask).astype(np.uint8)
        else:
            final_art = cv2.addWeighted(oil_painted, 0.65, high_pass, 0.35, 0)

    # Contrast adjustment
    lab = cv2.cvtColor(final_art, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=1.4, tileGridSize=(8, 8))
    cl = clahe.apply(l)
    enhanced_lab = cv2.merge((cl, a, b))
    
    return cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

@app.route('/process', methods=['POST'])
def process_image():
    if 'image' not in request.files:
        return "No image uploaded", 400
    
    file = request.files['image']
    
    unit_category = request.form.get('unit_category', 'standard')
    override_enabled = request.form.get('override_enabled', 'false').lower() == 'true'
    bypass_filter = request.form.get('bypass_filter', 'false').lower() == 'true'
    intensity = request.form.get('intensity', 'medium')

    # Determine processing mode
    if bypass_filter:
        mode = 'bypass'
    elif override_enabled:
        if unit_category in ['masked', 'droid']:
            mode = 'armor'
        elif unit_category == 'creature':
            mode = 'full_paint'
        else:
            mode = 'human'
    else:
        mode = 'human'

    in_memory_file = file.read()
    nparr = np.frombuffer(in_memory_file, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        return "Invalid image file", 400

    processed_img = apply_painterly_effect(img, mode=mode, intensity=intensity)

    is_success, buffer = cv2.imencode(".png", processed_img)
    if not is_success:
        return "Image processing failed", 500

    io_buf = io.BytesIO(buffer)
    return send_file(io_buf, mimetype='image/png')

if __name__ == '__main__':
    app.run(port=5000, debug=True)