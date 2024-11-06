import cv2
import numpy as np

# Load the image
image = cv2.imread('/Users/jc/Documents/GitHub/6205-final-project/sim/humans.jpg')
count = 0

binary = np.ones((np.shape(image)[0], np.shape(image)[1],1))

for i in range(np.shape(image)[0]):
  for j in range(np.shape(image)[1]):
    if (np.sum(image[i,j]) > 650) and (np.sum(image[i,j]) < 750):
      binary[i,j] = 0
      print(np.sum(image[i,j]))
    else:
      binary[i,j] = 1
print(count)

# Get the RGB value of the top-left pixel
top_left_pixel = image[0, 0]

# Create a binary mask
mask = np.all(image == top_left_pixel, axis=-1).astype(np.uint8)

# Invert the mask to match the requirement (0 for same RGB, 1 for different RGB)
binary_mask = 1 - mask

# Save the binary mask as an image
cv2.imwrite('binary_mask_1bit.png', binary * 255)

def calculate_A(p):
    count = 0
    for k in range(1, len(p)-1):
        if p[k] == 0 and p[k + 1] == 1:
            count += 1
    if p[-1] == 0 and p[1] == 1:  # wrap around for the circular pattern
        count += 1
    return count

NUM_ITERS = 100
for _ in range(NUM_ITERS):
  for i in range(1, np.shape(image)[0]-1):
    for j in range(1, np.shape(image)[1]-1):
      p = [
          binary[i, j],      # p1
          binary[i, j-1],    # p2
          binary[i+1, j-1],  # p3
          binary[i+1, j],    # p4
          binary[i+1, j+1],  # p5
          binary[i, j+1],    # p6
          binary[i-1, j+1],  # p7
          binary[i-1, j],    # p8
          binary[i-1, j-1]   # p9
      ]

      B_p = sum(p[1:]) # neighbors of p1
      A_p = calculate_A(p)
      p246 = p[1] * p[3] * p[5] # p2 * p4* p6
      p468 = p[3] * p[5] * p[7] # p4 * p6 * p8

      if (B_p >= 2) and (B_p <= 6) and (A_p == 1) and (p246 == 0) and (p468 == 0):
          if binary[i, j] == 1:
              binary[i, j] = 0


cv2.imwrite('binary_mask_1bit_skeleton.png', binary * 255)