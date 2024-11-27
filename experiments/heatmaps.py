import numpy as np
from scipy.ndimage import distance_transform_edt
from skeleton_copy import calc_binary, skeletonization
import cv2
from pathlib import Path

cwd = Path(__file__).parent
def create_heatmap(file_path):
  # Ensure the input is a numpy array
  input_array = calc_binary(file_path)
  
  binary = skeletonization(input_array)
  # Compute the distance transform
  distance = distance_transform_edt(binary == 0)
   
  # Cap the distance values at 7 and convert to integers
  heatmap = (np.clip(distance, 0, 21)/3).astype(int)
  
  return heatmap

# Example usage
if __name__ == "__main__":
  
  heatmap = create_heatmap("humans.jpg")
  cv2.imwrite(str(cwd / "humans_heatmap.png"), heatmap * 36)