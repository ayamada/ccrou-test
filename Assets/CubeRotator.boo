import UnityEngine

class CubeRotator (MonoBehaviour):
  public targetObj as Transform
  public rotateSpeed = Vector3(0.11, 0.17, 0.29)

  def Start ():
    pass

  def Update ():
    if targetObj != null:
      targetObj.Rotate(rotateSpeed)
