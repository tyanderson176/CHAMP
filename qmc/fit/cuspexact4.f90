      subroutine cuspexact4(iprin,iwf)
! Written by Cyrus Umrigar

      use atom_mod
      use jaspar3_mod
      use jaspar4_mod
      use cuspmat4_mod
      implicit real*8(a-h,o-z)


! For Jastrow4 NEQSX=2*(MORDJ-1) is sufficient.
! For Jastrow3 NEQSX=2*MORDJ should be sufficient.
! I am setting NEQSX=6*MORDJ simply because that is how it was for
! Jastrow3 for reasons I do not understand.

! The last 2 columns are what we care about in the foll. table
!------------------------------------------------------------------------------
! ord  # of   cumul.    # terms  # terms   # 3-body  Cumul. #      Cumul # indep
!      terms  # terms   even t   odd t      terms    3-body terms  3-body terms
!  n  (n+1)* (n^3+5n)/6         int((n+1)/2            nterms
!    (n+2)/2  +n^2+n           *int((n+2)/2
!------------------------------------------------------------------------------
!  1     3       3        2         1          0         0              0
!  2     6       9        4         2          2         2              0
!  3    10      19        6         4          4         6              2
!  4    15      34        9         6          7        13              7
!  5    21      55       12         9         10        23             15
!  6    28      83       16        12         14        37             27
!  7    36     119       20        16         18        55             43
!------------------------------------------------------------------------------

! Dependent coefs. fixed by e-e and e-n cusp conditions resp. are;
! order:   2  3  4  5  6  7  2  3  4  5  6  7
! coefs:   1  410 1932 49  2  612 2235 53

! So the terms varied for a 5th, 6th order polynomial are:
!    3   5   78 9    11    1314 1516 1718    2021    23 (iwjasc(iparm),iparm=1,nparmc)
!    3   5   78 9    11    1314 1516 1718    2021    2324 2526 2728 2930 31    3334    3637 (iwjasc(iparm),iparm=1,nparmc)


! All the dependent variables, except one (the one from the 2nd order
! e-n cusp) depend only on independent variables.  On the other hand
! the one from the 2nd order e-n cusp depends only on other dependent
! variables.

      do 100 it=1,nctype

! Set dep. variables from e-e cusp
        do 20 i=1,nordc-1
          sum=0
          do 10 j=1,nterms
   10       if(j.ne.iwc4(i)) sum=sum+d(i,j)*c(j,it,iwf)
   20     c(iwc4(i),it,iwf)=-sum/d(i,iwc4(i))

! Set dep. variables from 3rd and higher order e-n cusp
        do 40 i=nordc+1,2*(nordc-1)
          sum=0
          do 30 j=1,nterms
   30       if(j.ne.iwc4(i)) sum=sum+d(i,j)*c(j,it,iwf)
   40     c(iwc4(i),it,iwf)=-sum/d(i,iwc4(i))

! Set dep. variables from 2nd order e-n cusp
        if(nordc.gt.1) then
          i=nordc
          sum=0
          do 50 j=1,nterms
   50       if(j.ne.iwc4(i)) sum=sum+d(i,j)*c(j,it,iwf)
          c(iwc4(i),it,iwf)=-sum/d(i,iwc4(i))
        endif

 100  continue

      return
      end
