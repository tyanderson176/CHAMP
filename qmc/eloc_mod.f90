module eloc_mod

  use all_tools_mod
  use electrons_mod
  use psi_mod

! Declaration of global variables and default values
  real(dp)                       :: elocf90
  real(dp)                       :: elocf90_av
  real(dp)                       :: elocf90_av_err
  real(dp)                       :: eloc
  real(dp)                       :: eloc_bav
  real(dp)                       :: eloc_av
  real(dp)                       :: eloc_av_var
  real(dp)                       :: eloc_av_err
  real(dp)                       :: eloc_kin
  real(dp)                       :: eloc_kin_av
  real(dp)                       :: eloc_kin_av_err
  real(dp)                       :: eloc_pot
  real(dp)                       :: eloc_pot_loc
  real(dp)                       :: eloc_pot_nloc
  real(dp)                       :: pe_en
  real(dp)                       :: pe_ee
  real(dp)                       :: eloc_pot_en
  real(dp)                       :: eloc_pot_en_av
  real(dp)                       :: eloc_pot_ee
  real(dp)                       :: eloc_pot_ee_av
  real(dp)                       :: eloc_pot_ee_av_err
  real(dp)                       :: eloc_pot_ee_zv
  real(dp)                       :: eloc_pot_ee_zv_av
  real(dp)                       :: eloc_pot_ee_zv_av_err
  real(dp)                       :: eloc_kin_jas
  real(dp)                       :: eloc_kin_jas_av
  real(dp)                       :: eloc_kin_jas_av_err
  real(dp)                       :: eloc_kin_jas_pot_ee_av
  real(dp)                       :: eloc_kin_jas_pot_ee_av_err

  contains

! ==============================================================================
  subroutine eloc_kin_bld
! ------------------------------------------------------------------------------
! Description   : Kinetic local energy
!
! Created       : J. Toulouse, 05 Dec 2005
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

! local
  integer dim_i, elec_i
  real(dp) sum_grd_psi_over_psi_square

! header
  if (header_exe) then

   call object_create ('eloc_kin')

   call object_needed ('ndim')
   call object_needed ('nelec')
   call object_needed ('sum_lap_lnpsi')
   call object_needed ('grd_psi_over_psi_wlk')

   return

  endif

! begin

! allocations
  call object_associate ('eloc_kin', eloc_kin)
  call object_associate ('eloc_kin_av', eloc_kin_av)
  call object_associate ('eloc_kin_av_err', eloc_kin_av_err)

  sum_grd_psi_over_psi_square = 0.d0

  do dim_i = 1, ndim
    do elec_i = 1, nelec
       sum_grd_psi_over_psi_square = sum_grd_psi_over_psi_square + grd_psi_over_psi_wlk (dim_i, elec_i, 1)**2
    enddo
  enddo

  eloc_kin =  -0.5d0 * (sum_lap_lnpsi + sum_grd_psi_over_psi_square)

 end subroutine eloc_kin_bld

! ==============================================================================
  subroutine elocf90_bld
! ------------------------------------------------------------------------------
! Description   : total local energy
! Description   : alternative to eloc which is directly set to eold in f77 code
!
! Created       : J. Toulouse, 18 Feb 2016
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

! header
  if (header_exe) then

   call object_create ('elocf90')
   call object_average_define ('elocf90', 'elocf90_av')
   call object_error_define ('elocf90_av', 'elocf90_av_err')

   call object_needed ('eloc_kin')
   call object_needed ('eloc_pot')

   return

  endif

! begin
!  write(6,*) trim(here),': entering'

! allocations
  call object_associate ('elocf90', elocf90)
  call object_associate ('elocf90_av', elocf90_av)
  call object_associate ('elocf90_av_err', elocf90_av_err)

  elocf90 = eloc_kin + eloc_pot

 end subroutine elocf90_bld

! ==============================================================================
  subroutine eloc_pot_en_bld
! ------------------------------------------------------------------------------
! Description   : electron-nucleus local potential energy
!
! Created       : J. Toulouse, 18 May 2007
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

! header
  if (header_exe) then

   call object_create ('eloc_pot_en')
   call object_average_define ('eloc_pot_en', 'eloc_pot_en_av')

   call object_needed ('pe_en')

   return

  endif

! begin

! allocations
  call object_associate ('eloc_pot_en', eloc_pot_en)
  call object_associate ('eloc_pot_en_av', eloc_pot_en_av)

  eloc_pot_en = pe_en

 end subroutine eloc_pot_en_bld

! ==============================================================================
  subroutine eloc_pot_ee_bld
! ------------------------------------------------------------------------------
! Description   : electron-electron local potential energy
!
! Created       : J. Toulouse, 18 May 2007
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

! header
  if (header_exe) then

   call object_create ('eloc_pot_ee')
   call object_average_define ('eloc_pot_ee', 'eloc_pot_ee_av')
   call object_error_define ('eloc_pot_ee_av', 'eloc_pot_ee_av_err')

   call object_needed ('pe_ee')

   return

  endif

! begin

! allocations
  call object_associate ('eloc_pot_ee', eloc_pot_ee)
  call object_associate ('eloc_pot_ee_av', eloc_pot_ee_av)
  call object_associate ('eloc_pot_ee_av_err', eloc_pot_ee_av_err)

  eloc_pot_ee = pe_ee

 end subroutine eloc_pot_ee_bld

! ==============================================================================
  subroutine eloc_pot_ee_zv_bld
! ------------------------------------------------------------------------------
! Description   : zero-variance estimator of electron-electron local potential energy
! Description   : -(1/2) sim_{i!=j} (grad_j Psi)/Psi . r_ij / |r_ij|
!
! Created       : J. Toulouse, 03 Jul 2009
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

  integer elec_i, elec_j, dim_i
  real(dp) dij, dotproduct

! header
  if (header_exe) then

   call object_create ('eloc_pot_ee_zv')
   call object_average_define ('eloc_pot_ee_zv', 'eloc_pot_ee_zv_av')
   call object_error_define ('eloc_pot_ee_zv_av', 'eloc_pot_ee_zv_av_err')

   call object_needed ('nelec')
   call object_needed ('ndim')
   call object_needed ('grd_psi_over_psi_wlk')
   call object_needed ('vec_ee_xyz_wlk')
   call object_needed ('dist_ee_wlk')


   return

  endif

! begin

! allocations
  call object_associate ('eloc_pot_ee_zv', eloc_pot_ee_zv)
  call object_associate ('eloc_pot_ee_zv_av', eloc_pot_ee_zv_av)
  call object_associate ('eloc_pot_ee_zv_av_err', eloc_pot_ee_zv_av_err)

  eloc_pot_ee_zv = 0.d0

  do elec_j = 1, nelec
    do elec_i = 1, nelec

      if (elec_i == elec_j) cycle

!     distance e-e
      dij = dist_ee_wlk (elec_i, elec_j, 1)

!     dot product: drift_j . (rj - ri)
      dotproduct = 0.d0
      do dim_i = 1, ndim
        dotproduct = dotproduct +  grd_psi_over_psi_wlk (dim_i, elec_j, 1) * vec_ee_xyz_wlk (dim_i, elec_j, elec_i, 1)
      enddo

      eloc_pot_ee_zv = eloc_pot_ee_zv - (dotproduct / dij) * 0.5d0

    enddo !elec_j
  enddo !elec_i

 end subroutine eloc_pot_ee_zv_bld

! ==============================================================================
  subroutine eloc_kin_jas_bld
! ------------------------------------------------------------------------------
! Description   : (1/2) \sum_i [Grad_i (Jastrow) / Jastrow] . [Grad_i (Jastrow) / Jastrow]
!
! Created       : J. Toulouse, 22 Jun 2009
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none
  integer dim_i, elec_i

! header
  if (header_exe) then

   call object_create ('eloc_kin_jas')
   call object_average_define ('eloc_kin_jas', 'eloc_kin_jas_av')
   call object_error_define ('eloc_kin_jas_av', 'eloc_kin_jas_av_err')

   call object_needed ('nelec')
   call object_needed ('ndim')
   call object_needed ('vj')

   return

  endif

! begin

! allocations
  call object_associate ('eloc_kin_jas', eloc_kin_jas)
  call object_associate ('eloc_kin_jas_av', eloc_kin_jas_av)
  call object_associate ('eloc_kin_jas_av_err', eloc_kin_jas_av_err)

  eloc_kin_jas = 0.d0

  do elec_i = 1, nelec
    do dim_i = 1, ndim 
      eloc_kin_jas = eloc_kin_jas + vj (dim_i, elec_i) * vj (dim_i, elec_i)
    enddo
  enddo

  eloc_kin_jas = 0.5d0 * eloc_kin_jas
  
 end subroutine eloc_kin_jas_bld

! ==============================================================================
  subroutine eloc_kin_jas_pot_ee_av_bld
! ------------------------------------------------------------------------------
! Description   : 
!
! Created       : J. Toulouse, 22 Jun 2009
! ------------------------------------------------------------------------------
  include 'modules.h'
  implicit none

! header
  if (header_exe) then

   call object_create ('eloc_kin_jas_pot_ee_av')
   call object_error_define ('eloc_kin_jas_pot_ee_av', 'eloc_kin_jas_pot_ee_av_err')

   call object_needed ('eloc_kin_jas_av')
   call object_needed ('eloc_pot_ee_av')

   return

  endif

! begin

! allocations
  call object_associate ('eloc_kin_jas_pot_ee_av', eloc_kin_jas_pot_ee_av)
  call object_associate ('eloc_kin_jas_pot_ee_av_err', eloc_kin_jas_pot_ee_av_err)

  eloc_kin_jas_pot_ee_av = eloc_kin_jas_av + eloc_pot_ee_av
  
 end subroutine eloc_kin_jas_pot_ee_av_bld

end module eloc_mod
