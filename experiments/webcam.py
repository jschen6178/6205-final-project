import cv2
import numpy as np

# Open the default camera
cam = cv2.VideoCapture(0)

# Get the default frame width and height
frame_width = int(cam.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cam.get(cv2.CAP_PROP_FRAME_HEIGHT))

# Define the codec and create VideoWriter object
fourcc = cv2.VideoWriter_fourcc(*"mp4v")
out = cv2.VideoWriter("output.mp4", fourcc, 20.0, (frame_width, frame_height))

sobelx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])
sobely = np.array([[1, 2, 1], [0, 0, 0], [-1, -2, -1]])
sobelxy = sobelx + sobely

while True:
    # ret, frame = cam.read()
    #
    # # Write the frame to the output file
    # out.write(frame)
    #
    # # Display the captured frame
    # cv2.imshow("Camera", frame)
    #
    # # Press 'q' to exit the loop
    # if cv2.waitKey(1) == ord("q"):
    #     break
    # Take each frame
    _, frame = cam.read()

    # Calculation of Sobelx
    sobelx = cv2.filter2D(frame, -1, sobelx)

    # Calculation of Sobely
    sobely = cv2.filter2D(frame, -1, sobely)

    sobelxy = cv2.filter2D(frame, -1, sobelxy)

    cv2.imshow("sobelx", sobelx)
    cv2.imshow("sobely", sobely)
    cv2.imshow("sum", sobelxy)
    k = cv2.waitKey(5) & 0xFF
    if k == 27:
        break

# Release the capture and writer objects
cam.release()
out.release()
cv2.destroyAllWindows()
