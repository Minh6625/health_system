from PIL import Image
import os

def resize_image(input_path, max_width, max_height):
    """Resize image maintaining aspect ratio"""
    img = Image.open(input_path)
    
    # Calculate new dimensions maintaining aspect ratio
    width_ratio = max_width / img.width
    height_ratio = max_height / img.height
    ratio = min(width_ratio, height_ratio)
    
    new_width = int(img.width * ratio)
    new_height = int(img.height * ratio)
    
    # Resize with high quality
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Save back to same file
    resized.save(input_path, 'PNG', optimize=True)
    
    file_size = os.path.getsize(input_path) / 1024  # KB
    print(f"✓ Resized {os.path.basename(input_path)}: {new_width}×{new_height}px, {file_size:.2f}KB")

if __name__ == "__main__":
    print("Resizing images...\n")
    
    # Resize logo.png to 300x263 for fastest decode
    resize_image("assets/images/logo.png", 300, 300)
    
    print("\nDone! Run 'flutter run' to see the improvement.")
