# BLEndIOS

This is an implementation of the BLEnd protocol using Swift for the iOS platform. 

For more information about BLEnd, see the paper:
C. Julien, C. Liu, A. L. Murphy and G. P. Picco, "BLEnd: Practical Continuous Neighbor Discovery for Bluetooth Low Energy," 2017 16th ACM/IEEE International Conference on Information Processing in Sensor Networks (IPSN), 2017, pp. 105-116.
https://ieeexplore.ieee.org/abstract/document/7944783

This implementation provides a template for integrating BLEnd in application space on iOS. However, the advertisement interval is fixed by the allowances of the iOS platform, especially when advertisement is running in the background.
