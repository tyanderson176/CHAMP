module distance_mod

 use constants_mod
 implicit none
 save

 double precision, allocatable :: rshift(:,:,:),rvec_en(:,:,:),r_en(:,:),rvec_ee(:,:),r_ee(:)

end module distance_mod