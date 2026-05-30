import os
import sys
from PIL import Image

def generate_iconset(source_png, output_iconset_dir):
    if not os.path.exists(source_png):
        print(f"Error: Source image {source_png} not found.")
        sys.exit(1)
        
    os.makedirs(output_iconset_dir, exist_ok=True)
    img = Image.open(source_png)
    
    # Standard macOS icon sizes: (size_name, dimension)
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    for filename, dim in sizes:
        resized = img.resize((dim, dim), Image.Resampling.LANCZOS)
        resized.save(os.path.join(output_iconset_dir, filename))
        print(f"Generated {filename} ({dim}x{dim})")

if __name__ == "__main__":
    src = "app_icon_raw.png"
    out = "AppIcon.iconset"
    generate_iconset(src, out)
    print("Successfully generated iconset.")
