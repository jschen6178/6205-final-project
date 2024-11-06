import cv2
import numpy as np
import time
from pathlib import Path

# Load the image
cwd = Path(__file__).parent
image = cv2.imread(str(cwd / "humans.jpg"))

binary = np.ones((np.shape(image)[0], np.shape(image)[1]))

for i in range(np.shape(image)[0]):
    for j in range(np.shape(image)[1]):
        if image[i, j, 2] < image[i, j, 0] - 16:
            binary[i, j] = 0
        else:
            binary[i, j] = 1

# Save the binary mask as an image
cv2.imwrite(str(cwd / "binary_mask_1bit.png"), binary * 255)


def calculate_A(p):
    count = 0
    for k in range(len(p)):
        if p[k] == 0 and p[(k + 1) % len(p)] == 1:
            count += 1
    return count

dx = np.array([0, -1, -1, 0, 1, 1, 1, 0, -1])
dy = np.array([0, 0, 1, 1, 1, 0, -1, -1, -1])

NUM_ITERS = 100
for _ in range(NUM_ITERS):
    print(f"Iteration {_}")
    count = 0
    new_image = binary.copy()
    for i in range(1, np.shape(image)[0] - 1):
        for j in range(1, np.shape(image)[1] - 1):
            p = binary[i + dx, j + dy]

            B_p = np.sum(p[1:])  # neighbors of p1
            A_p = calculate_A(p[1:])
            p246 = p[1] * p[3] * p[5]  # p2 * p4 * p6
            p468 = p[3] * p[5] * p[7]  # p4 * p6 * p8

            if (
                2 <= B_p <= 6
                and A_p == 1
                and p246 == 0
                and p468 == 0
                and binary[i, j] == 1
            ):
                new_image[i, j] = 0
                count += 1
    binary = new_image.copy()
    if count == 0:
        break
    count = 0
    for i in range(1, np.shape(image)[0] - 1):
        for j in range(1, np.shape(image)[1] - 1):
            p = binary[i + dx, j + dy]

            B_p = np.sum(p[1:])  # neighbors of p1
            A_p = calculate_A(p[1:])
            p248 = p[1] * p[3] * p[7]  # p2 * p4 * p8
            p268 = p[1] * p[5] * p[7]  # p2 * p6 * p8

            if (
                2 <= B_p <= 6
                and A_p == 1
                and p248 == 0
                and p268 == 0
                and binary[i, j] == 1
            ):
                new_image[i, j] = 0
                count += 1
    binary = new_image
    if count == 0:
        break


cv2.imwrite(str(cwd / "binary_mask_1bit_skeleton.png"), binary * 255)
