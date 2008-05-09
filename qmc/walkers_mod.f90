module walkers_mod

  use all_tools_mod
  use restart_mod

! Declaration of global variables and default values
  character (len=max_string_len_file)   :: file_mc_configs_in  = 'mc_configs'
  character (len=max_string_len_file)   :: file_mc_configs_out = 'mc_configs_new'
  logical :: l_check_initial_walkers = .false.
  logical :: l_keep_only_walkers_with_elec_nb_closest_to_atom_input = .false.
  real(dp), allocatable                 :: elec_nb_closest_to_atom_input (:)
!  real(dp), allocatable                 :: elec_spin_nb_closest_to_atom_input (:)
  real(dp), allocatable                 :: elec_up_nb_closest_to_atom_input (:)
  real(dp), allocatable                 :: elec_dn_nb_closest_to_atom_input (:)
  character (len=max_string_len_file)   :: file_walkers_out = ''
  logical :: l_write_walkers = .false.
  integer :: write_walkers_step = 1
  integer :: file_walkers_out_unit

  contains

!===========================================================================
  subroutine walkers_menu
!---------------------------------------------------------------------------
! Description : menu for walkers
!
! Created     : J. Toulouse, 01 Apr 2007
!---------------------------------------------------------------------------
  implicit none
  include 'commons.h'

! local
  character(len=max_string_len_rout), save :: lhere = 'walkers_menu'
  integer elec_nb_closest_to_atom_input_nb
  integer elec_up_nb_closest_to_atom_input_nb
  integer elec_dn_nb_closest_to_atom_input_nb

! begin

! loop over menu lines
  do
  call get_next_word (word)

  select case (trim(word))
  case ('help')
   write(6,*)
   write(6,'(a)') 'HELP for walkers menu:'
   write(6,'(a)') ' walkers'
   write(6,'(a)') '  file_mc_configs_in  = [string] : input file for walkers (default=mc_configs).'
   write(6,'(a)') '  file_mc_configs_out = [string] : output file for walkers (default=mc_configs_new).'
   write(6,'(a)') '  check_initial_walkers = [string] : check electrons distribution on atoms in initial walkers (default=false).'
   write(6,'(a)') '  elec_nb_closest_to_atom 6 2 5 end : keep only walkers with these electron numbers closest to each atom.'
   write(6,'(a)') '  keep_only_walkers_with_elec_nb_closest_to_atom_input = [bool] : default = false.'
   write(6,'(a)') '  file_walkers_out  = [string] : output file for walkers in Scemama format'
   write(6,'(a)') '  write_walkers = [logical] write walkers in Scemama format (default=false)'
   write(6,'(a)') '  write_walkers_step = [integer] write walkers in Scemama format every X step? (default=1)'
   write(6,'(a)') ' end'
   write(6,*)

  case ('file_mc_configs_in')
   call get_next_value (file_mc_configs_in)

  case ('file_mc_configs_out')
   call get_next_value (file_mc_configs_out)

  case ('check_initial_walkers')
   call get_next_value (l_check_initial_walkers)

  case ('elec_nb_closest_to_atom')
   call get_next_value_list ('elec_nb_closest_to_atom_input', elec_nb_closest_to_atom_input, elec_nb_closest_to_atom_input_nb)
   call object_provide ('ncent')
   if (elec_nb_closest_to_atom_input_nb /= ncent) then
    write(6,'(3a,i3,a,i3)') 'Fatal error in routine ',trim(lhere),': ',elec_nb_closest_to_atom_input_nb,' values read in list elec_nb_closest_to_atom while the expected number was the number of atom centers = ',ncent
   call die (lhere)
   endif
   call object_modified ('elec_nb_closest_to_atom_input')

  case ('elec_up_nb_closest_to_atom')
   call get_next_value_list ('elec_up_nb_closest_to_atom_input', elec_up_nb_closest_to_atom_input, elec_up_nb_closest_to_atom_input_nb)
   call object_provide ('ncent')
   if (elec_up_nb_closest_to_atom_input_nb /= ncent) then
    write(6,'(3a,i3,a,i3)') 'Fatal error in routine ',trim(lhere),': ',elec_up_nb_closest_to_atom_input_nb,' values read in list elec_up_nb_closest_to_atom while the expected number was the number of atom centers = ',ncent
   call die (lhere)
   endif
   call object_modified ('elec_up_nb_closest_to_atom_input')

  case ('elec_dn_nb_closest_to_atom')
   call get_next_value_list ('elec_dn_nb_closest_to_atom_input', elec_dn_nb_closest_to_atom_input, elec_dn_nb_closest_to_atom_input_nb)
   call object_provide ('ncent')
   if (elec_dn_nb_closest_to_atom_input_nb /= ncent) then
    write(6,'(3a,i3,a,i3)') 'Fatal error in routine ',trim(lhere),': ',elec_dn_nb_closest_to_atom_input_nb,' values read in list elec_dn_nb_closest_to_atom while the expected number was the number of atom centers = ',ncent
   call die (lhere)
   endif
   call object_modified ('elec_dn_nb_closest_to_atom_input')

  case ('keep_only_walkers_with_elec_nb_closest_to_atom_input')
   call get_next_value (l_keep_only_walkers_with_elec_nb_closest_to_atom_input)

  case ('file_walkers_out')
   call get_next_value (file_walkers_out)
   call open_file_or_die (file_walkers_out, file_walkers_out_unit)

  case ('write_walkers')
   call get_next_value (l_write_walkers)

  case ('write_walkers_step')
   call get_next_value (write_walkers_step)

  case ('end')
   exit

  case default
   call die (lhere, 'unknown keyword >'+trim(word)+'<')
  end select

  enddo ! end loop over menu lines

  end subroutine walkers_menu

! ==============================================================================
  subroutine get_initial_walkers
! ------------------------------------------------------------------------------
! Description   : get initial walkers for DMC
!
! Created       : J. Toulouse, 22 Mar 2007
! ------------------------------------------------------------------------------
  implicit none
  include 'commons.h'

! local
  character (len=max_string_len_rout), save :: lhere = 'get_initial_walkers'
  integer walk_i, elec_i, elec_j, dim_i
  real(dp) dist
  logical ok

! begin
  write(6,*)
  write(6,'(a)') 'Initial walkers:'

! walkers from restart file
  if (irstar.eq.1) then
    if(idmc.lt.0) then
      if(index(mode,'mov1').ne.0) then
        open(10,file='restart_dmcvmc_mov1',status='old',form='unformatted')
      else
        open(10,file='restart_dmcvmc',status='old',form='unformatted')
      endif
    else
      if(index(mode,'mov1').ne.0) then
        open(10,file='restart_dmc_mov1',status='old',form='unformatted')
      else
        open(10,file='restart_dmc',status='old',form='unformatted')
      endif
    endif
    rewind 10
   call startr_dmc
   close (unit=10)

! try to read walkers from file_mc_configs_in
  elseif (file_exist (file_mc_configs_in)) then
   call read_initial_walkers (ok)

!  if no walker read
   if (.not. ok) then
     if (idmc < 0) then
       nconf=1
       write(6,'(a)') 'Warning: no walkers read. Generate randomly one walker.'
       call sites_per (xoldw,nelec,nup,ndn,rlatt_sim)
     else
       call die ('No walker read in file >'+trim(file_mc_configs_in)+'<.')
     endif ! if idmc <0

    endif ! if not ok


! if walker file does not exist
  else

     if (idmc < 0) then
       nconf=1
       write(6,'(a)') 'Warning: walker file does not exist. Generate randomly one walker.'
       call sites_per (xoldw,nelec,nup,ndn,rlatt_sim)
     else
       call die (lhere, 'Walker file does not exist >'+trim(file_mc_configs_in)+'<. First run in vmc mode to generate it.')
     endif ! if idmc <0

  endif

! mark as valid object xoldw
  call object_modified ('xoldw')

! Check that there are no very close electron pairs.
  do walk_i = 1, nconf
    do elec_i = 1, nelec
      do elec_j = elec_i + 1, nelec
         dist=0
         do dim_i = 1, ndim
            dist=dist+(xoldw(dim_i,elec_i,walk_i,1)-xoldw(dim_i,elec_j,walk_i,1))**2
         enddo ! dim_i
         if (dist < 1.d-24) then
            dist=sqrt(dist)
            write(6,'(a,i5,a,i3,a,i3,a)') 'Error: in walker # ',walk_i,', electrons ',elec_i,' and ',elec_j, ' are too close.'
            call die (lhere, 'two electrons are close in a walker.')
         endif
       enddo ! elec_j
     enddo ! elec_i
   enddo ! walk_i

  write(6,*)

  end subroutine get_initial_walkers

! ==============================================================================
  subroutine read_initial_walkers (ok)
! ------------------------------------------------------------------------------
! Description   : read initial walkers for DMC
!
! Created       : J. Toulouse, 01 Apr 2007
! Modified      : R. G. Hennig, April 2008, Read walkers on master node & bcast
! ------------------------------------------------------------------------------
  USE mpi_mod
  implicit none
  include 'commons.h'



! output
  logical ok

! local
  character (len=max_string_len_rout), save :: lhere = 'read_initial_walkers'
  real(dp), allocatable :: coord_elec_read (:,:)
  real(dp), allocatable :: coord_elec_wlk_read (:,:,:)
  real(dp), allocatable :: dist_ee_wlk_read (:,:,:)
  real(dp), allocatable :: dist_en_wlk_read (:,:,:)
  real(dp), allocatable :: elec_nb_closest_to_atom_wlk_read (:,:)
  real(dp), allocatable :: elec_up_nb_closest_to_atom_wlk_read (:,:)
  real(dp), allocatable :: elec_dn_nb_closest_to_atom_wlk_read (:,:)
  real(dp), allocatable :: elec_nb_closest_to_atom_read (:,:)
  real(dp), allocatable :: elec_up_nb_closest_to_atom_read (:,:)
  real(dp), allocatable :: elec_dn_nb_closest_to_atom_read (:,:)
  integer, allocatable  :: elec_nb_closest_to_atom_wlk_read_nb (:)
  integer, allocatable  :: elec_up_nb_closest_to_atom_wlk_read_nb (:)
  integer, allocatable  :: elec_dn_nb_closest_to_atom_wlk_read_nb (:)
  integer               :: elec_nb_closest_to_atom_read_nb, elec_nb_closest_to_atom_read_i
  integer               :: elec_up_nb_closest_to_atom_read_nb, elec_up_nb_closest_to_atom_read_i
  integer               :: elec_dn_nb_closest_to_atom_read_nb, elec_dn_nb_closest_to_atom_read_i
  integer :: dim_i, elec_i, elec_j, walk_i, walk_mod_i, cent_closest_i, walk_j, cent_i
  integer nconf_read, nconf_missing, nconf_dropped, nconf_unique
  integer file_unit, iostat, ierr
  logical found, walker_not_unique

! begin
  ok = .true.
  nconf_read = 0

! objects needed
  call object_provide ('ndim')
  call object_provide ('nelec')
  call object_provide ('ncent')
  call object_provide ('nconf')

#ifdef MPI
 if(idtask == 0) then
#endif

! check file exists
     call file_exist_or_die (file_mc_configs_in)

! open file
     file_unit = 0
     call open_file_or_die (file_mc_configs_in, file_unit)

! allocation
     call alloc ('coord_elec_read', coord_elec_read, ndim, nelec)

! loop over lines in file
     call alloc ('coord_elec_wlk_read', coord_elec_wlk_read, ndim, nelec, nconf_total)
     do
        read(file_unit,fmt=*,iostat=iostat) ((coord_elec_read (dim_i, elec_i), dim_i=1,ndim), elec_i=1,nelec)
        if (iostat /= 0) exit
        nconf_read = nconf_read + 1
        coord_elec_wlk_read (:,:,nconf_read) = coord_elec_read (:,:)
        if (nconf_read >= nconf_total) exit
     enddo ! end of loop over lines

! close file
     close(file_unit)

     write(6,'(i5,3a)') nconf_read,' walkers read from file >',trim(file_mc_configs_in),'<'

! if no walkers read, return
     if (nconf_read <= 0) then
        ok = .false.
        return
     endif

#ifdef MPI
  endif

  CALL MPI_BCAST(nconf_read, 1, MPI_INTEGER, 0, MPI_COMM_WORLD,ierr)

  if(idtask /= 0) then
     call alloc ('coord_elec_wlk_read', coord_elec_wlk_read, ndim, nelec, nconf_total)
  endif

  CALL MPI_BCAST(coord_elec_wlk_read, ndim*nelec*nconf_total, MPI_DOUBLE_PRECISION, 0, MPI_COMM_WORLD, ierr)

#endif

! Analyse walker population:

! Check uniqueness of walkers
  nconf_unique = nconf_read
  do walk_i = 1, nconf_read
    walker_not_unique = .false.
    do walk_j = walk_i +1, nconf_read
     if (arrays_equal (coord_elec_wlk_read (:,:, walk_i), coord_elec_wlk_read (:,:, walk_j))) then
      walker_not_unique = .true.
      exit
!      write(6,*)
!      write(6,'(a,i5,a,i5,a)') 'Warning: walker #', walk_i,' and #',walk_j,' are identical.'
     endif
    enddo ! walk_j
    if (walker_not_unique) nconf_unique = nconf_unique - 1
  enddo ! walk_i
  if (nconf_unique /= nconf_read) then
    write(6,'(a,i5,a)') 'Warning: there are only ',nconf_unique,' unique walkers.'
  endif

! Check electron-electron distances
  call alloc ('dist_ee_wlk_read', dist_ee_wlk_read, nelec, nelec, nconf_read)
  dist_ee_wlk_read (:,:,:) = 0.d0
  do walk_i = 1, nconf_read
    do elec_i = 1, nelec
      do elec_j = elec_i+1, nelec
        do dim_i = 1, ndim
          dist_ee_wlk_read (elec_i, elec_j, walk_i) = dist_ee_wlk_read (elec_i, elec_j, walk_i) &
               + (coord_elec_wlk_read (dim_i, elec_i, walk_i) - coord_elec_wlk_read (dim_i, elec_j, walk_i))**2
        enddo ! dim_i
        dist_ee_wlk_read (elec_i, elec_j, walk_i) = dsqrt (dist_ee_wlk_read (elec_i, elec_j, walk_i))
        dist_ee_wlk_read (elec_j, elec_i, walk_i) = dist_ee_wlk_read (elec_i, elec_j, walk_i)
        if (dist_ee_wlk_read (elec_i, elec_j, walk_i) < 1.d-12) then
           write(6,*)
           write(6,'(a,i5,a,i3,a,i3,a)') 'Error: in walker # ',walk_i,', electrons ',elec_i,' and ',elec_j, ' are too close.'
           write(6,'(a,f)') 'They are at a distance of ',dist_ee_wlk_read (elec_i, elec_j, walk_i), ' < 1.d-12.'
           call die (lhere, 'two electrons are too close in a walker.')
        endif
      enddo ! elec_j
    enddo ! elec_i
  enddo ! walk_i

! Check electron-nuclei distances
  call object_provide ('ncent')
  call object_provide ('cent')
  call alloc ('dist_en_wlk_read', dist_en_wlk_read, nelec, ncent, nconf_read)
  dist_en_wlk_read (:,:,:) = 0.d0
  do walk_i = 1, nconf_read
   do cent_i = 1, ncent
     do elec_i = 1, nelec
       do dim_i = 1, ndim
         dist_en_wlk_read (elec_i, cent_i, walk_i) = dist_en_wlk_read (elec_i, cent_i, walk_i)  &
              +   (coord_elec_wlk_read (dim_i, elec_i, walk_i) - cent (dim_i, cent_i))**2
       enddo ! dim_i
       dist_en_wlk_read (elec_i, cent_i, walk_i) = dsqrt (dist_en_wlk_read (elec_i, cent_i, walk_i))
       if (dist_en_wlk_read (elec_i, cent_i, walk_i) < 1.d-12) then
           write(6,*)
           write(6,'(a,i5,a,i3,a,i3)') 'Warning: in walker # ',walk_i,', electron #',elec_i,' is very close to nucleus #',cent_i
           write(6,'(a,f)') 'They are at a distance of ',dist_en_wlk_read (elec_i, cent_i, walk_i), ' < 1.d-12.'
       endif
      enddo ! elec_i
   enddo ! cent_i
  enddo ! walk_i

! Check number of electrons closest to each atoms
  if (l_check_initial_walkers) then
  call alloc ('elec_nb_closest_to_atom_wlk_read', elec_nb_closest_to_atom_wlk_read, ncent, nconf_read)
  call alloc ('elec_up_nb_closest_to_atom_wlk_read', elec_up_nb_closest_to_atom_wlk_read, ncent, nconf_read)
  call alloc ('elec_dn_nb_closest_to_atom_wlk_read', elec_dn_nb_closest_to_atom_wlk_read, ncent, nconf_read)
  elec_nb_closest_to_atom_wlk_read (:,:) = 0
  elec_up_nb_closest_to_atom_wlk_read (:,:) = 0
  elec_dn_nb_closest_to_atom_wlk_read (:,:) = 0
  do walk_i = 1, nconf_read
   do elec_i = 1, nelec
     cent_closest_i = 1
     do cent_i = 1, ncent
       if (dist_en_wlk_read (elec_i, cent_i, walk_i) < dist_en_wlk_read (elec_i, cent_closest_i, walk_i)) then
         cent_closest_i = cent_i
       endif
     enddo ! cent_i
     if (elec_i <= nup) then
      elec_up_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) =  elec_up_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) + 1
     else
      elec_dn_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) =  elec_dn_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) + 1
     endif
      elec_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) =  elec_nb_closest_to_atom_wlk_read (cent_closest_i, walk_i) + 1
   enddo ! elec_i
  enddo ! walk_i
  elec_nb_closest_to_atom_read_nb = 1
  elec_up_nb_closest_to_atom_read_nb = 1
  elec_dn_nb_closest_to_atom_read_nb = 1
  call alloc ('elec_nb_closest_to_atom_read', elec_nb_closest_to_atom_read, ncent, elec_nb_closest_to_atom_read_nb)
  call alloc ('elec_up_nb_closest_to_atom_read', elec_up_nb_closest_to_atom_read, ncent, elec_up_nb_closest_to_atom_read_nb)
  call alloc ('elec_dn_nb_closest_to_atom_read', elec_dn_nb_closest_to_atom_read, ncent, elec_dn_nb_closest_to_atom_read_nb)
  call alloc ('elec_nb_closest_to_atom_wlk_read_nb', elec_nb_closest_to_atom_wlk_read_nb, elec_nb_closest_to_atom_read_nb)
  call alloc ('elec_up_nb_closest_to_atom_wlk_read_nb', elec_up_nb_closest_to_atom_wlk_read_nb, elec_up_nb_closest_to_atom_read_nb)
  call alloc ('elec_dn_nb_closest_to_atom_wlk_read_nb', elec_dn_nb_closest_to_atom_wlk_read_nb, elec_dn_nb_closest_to_atom_read_nb)
  elec_nb_closest_to_atom_read (:, elec_nb_closest_to_atom_read_nb) = elec_nb_closest_to_atom_wlk_read (:, 1)
  elec_up_nb_closest_to_atom_read (:, elec_up_nb_closest_to_atom_read_nb) = elec_up_nb_closest_to_atom_wlk_read (:, 1)
  elec_dn_nb_closest_to_atom_read (:, elec_dn_nb_closest_to_atom_read_nb) = elec_dn_nb_closest_to_atom_wlk_read (:, 1)
  elec_nb_closest_to_atom_wlk_read_nb (elec_nb_closest_to_atom_read_nb) = 1
  elec_up_nb_closest_to_atom_wlk_read_nb (elec_up_nb_closest_to_atom_read_nb) = 1
  elec_dn_nb_closest_to_atom_wlk_read_nb (elec_dn_nb_closest_to_atom_read_nb) = 1

  do walk_i = 2, nconf_read
    found = .false.
    do elec_nb_closest_to_atom_read_i = 1, elec_nb_closest_to_atom_read_nb
      if (arrays_equal (elec_nb_closest_to_atom_wlk_read (:, walk_i), elec_nb_closest_to_atom_read (:, elec_nb_closest_to_atom_read_i))) then
         elec_nb_closest_to_atom_wlk_read_nb (elec_nb_closest_to_atom_read_i) = elec_nb_closest_to_atom_wlk_read_nb (elec_nb_closest_to_atom_read_i) + 1
        found = .true.
        exit
      endif
    enddo
   if (.not. found) then
     elec_nb_closest_to_atom_read_nb = elec_nb_closest_to_atom_read_nb + 1
     call alloc ('elec_nb_closest_to_atom_read', elec_nb_closest_to_atom_read, ncent, elec_nb_closest_to_atom_read_nb)
     call alloc ('elec_nb_closest_to_atom_wlk_read_nb', elec_nb_closest_to_atom_wlk_read_nb, elec_nb_closest_to_atom_read_nb)
     elec_nb_closest_to_atom_read (:, elec_nb_closest_to_atom_read_nb) = elec_nb_closest_to_atom_wlk_read (:, walk_i)
     elec_nb_closest_to_atom_wlk_read_nb (elec_nb_closest_to_atom_read_nb) = 1
   endif
  enddo ! walk_i

  do walk_i = 2, nconf_read
    found = .false.
    do elec_up_nb_closest_to_atom_read_i = 1, elec_up_nb_closest_to_atom_read_nb
      if (arrays_equal (elec_up_nb_closest_to_atom_wlk_read (:, walk_i), elec_up_nb_closest_to_atom_read (:, elec_up_nb_closest_to_atom_read_i))) then
         elec_up_nb_closest_to_atom_wlk_read_nb (elec_up_nb_closest_to_atom_read_i) = elec_up_nb_closest_to_atom_wlk_read_nb (elec_up_nb_closest_to_atom_read_i) + 1
        found = .true.
        exit
      endif
    enddo
   if (.not. found) then
     elec_up_nb_closest_to_atom_read_nb = elec_up_nb_closest_to_atom_read_nb + 1
     call alloc ('elec_up_nb_closest_to_atom_read', elec_up_nb_closest_to_atom_read, ncent, elec_up_nb_closest_to_atom_read_nb)
     call alloc ('elec_up_nb_closest_to_atom_wlk_read_nb', elec_up_nb_closest_to_atom_wlk_read_nb, elec_up_nb_closest_to_atom_read_nb)
     elec_up_nb_closest_to_atom_read (:, elec_up_nb_closest_to_atom_read_nb) = elec_up_nb_closest_to_atom_wlk_read (:, walk_i)
     elec_up_nb_closest_to_atom_wlk_read_nb (elec_up_nb_closest_to_atom_read_nb) = 1
   endif
  enddo ! walk_i

  do walk_i = 2, nconf_read
    found = .false.
    do elec_dn_nb_closest_to_atom_read_i = 1, elec_dn_nb_closest_to_atom_read_nb
      if (arrays_equal (elec_dn_nb_closest_to_atom_wlk_read (:, walk_i), elec_dn_nb_closest_to_atom_read (:, elec_dn_nb_closest_to_atom_read_i))) then
         elec_dn_nb_closest_to_atom_wlk_read_nb (elec_dn_nb_closest_to_atom_read_i) = elec_dn_nb_closest_to_atom_wlk_read_nb (elec_dn_nb_closest_to_atom_read_i) + 1
        found = .true.
        exit
      endif
    enddo
   if (.not. found) then
     elec_dn_nb_closest_to_atom_read_nb = elec_dn_nb_closest_to_atom_read_nb + 1
     call alloc ('elec_dn_nb_closest_to_atom_read', elec_dn_nb_closest_to_atom_read, ncent, elec_dn_nb_closest_to_atom_read_nb)
     call alloc ('elec_dn_nb_closest_to_atom_wlk_read_nb', elec_dn_nb_closest_to_atom_wlk_read_nb, elec_dn_nb_closest_to_atom_read_nb)
     elec_dn_nb_closest_to_atom_read (:, elec_dn_nb_closest_to_atom_read_nb) = elec_dn_nb_closest_to_atom_wlk_read (:, walk_i)
     elec_dn_nb_closest_to_atom_wlk_read_nb (elec_dn_nb_closest_to_atom_read_nb) = 1
   endif
  enddo ! walk_i

!  do walk_i = 1, nconf_read
!   do cent_i = 1, ncent
!     write(6,'(2a,i5,a,i3,a,f7.0)') trim(lhere),': walker #', walk_i,', atom #',cent_i,', number of closest electrons =',elec_nb_closest_to_atom_wlk_read (cent_i, walk_i)
!   enddo
!  enddo

  do elec_nb_closest_to_atom_read_i = 1, elec_nb_closest_to_atom_read_nb
     write(6,'(i5,a,100f7.0)') elec_nb_closest_to_atom_wlk_read_nb (elec_nb_closest_to_atom_read_i),' walkers have the following numbers of electrons closest to each atom:', elec_nb_closest_to_atom_read (:, elec_nb_closest_to_atom_read_i)
  enddo
  if (elec_nb_closest_to_atom_read_nb > 1) then
     write(6,'(a)') 'Warning: all walkers do not have the same numbers of electrons closest to each atom.'
  endif

  do elec_up_nb_closest_to_atom_read_i = 1, elec_up_nb_closest_to_atom_read_nb
     write(6,'(i5,a,100f7.0)') elec_up_nb_closest_to_atom_wlk_read_nb (elec_up_nb_closest_to_atom_read_i), &
   ' walkers have the following numbers of spin-up electrons closest to each atom:', elec_up_nb_closest_to_atom_read (:, elec_up_nb_closest_to_atom_read_i)
  enddo
  if (elec_up_nb_closest_to_atom_read_nb > 1) then
     write(6,'(a)') 'Warning: all walkers do not have the same numbers of spin-up electrons closest to each atom.'
  endif

  do elec_dn_nb_closest_to_atom_read_i = 1, elec_dn_nb_closest_to_atom_read_nb
     write(6,'(i5,a,100f7.0)') elec_dn_nb_closest_to_atom_wlk_read_nb (elec_dn_nb_closest_to_atom_read_i), &
   ' walkers have the following numbers of spin-down electrons closest to each atom:', elec_dn_nb_closest_to_atom_read (:, elec_dn_nb_closest_to_atom_read_i)
  enddo
  if (elec_dn_nb_closest_to_atom_read_nb > 1) then
     write(6,'(a)') 'Warning: all walkers do not have the same numbers of spin-down electrons closest to each atom.'
  endif

! Drop walkers with electron distributions on atoms different than requested in the input
  if (l_keep_only_walkers_with_elec_nb_closest_to_atom_input) then
   call object_provide ('elec_nb_closest_to_atom_input')
   nconf_dropped = 0
   do walk_i = 1, nconf_read
    if (.not. arrays_equal (elec_nb_closest_to_atom_wlk_read (:, walk_i), elec_nb_closest_to_atom_input (:))) then
      call remove_elt_in_array (coord_elec_wlk_read, walk_i - nconf_dropped)
      nconf_dropped = nconf_dropped + 1
!      write(6,'(2a,i5,a,100f7.0)') trim(lhere),': drop walker #', walk_i,', number of closest electrons =',elec_nb_closest_to_atom_wlk_read (:, walk_i)
    endif
   enddo
   nconf_read = nconf_read - nconf_dropped
   write (6, '(a, i5,a,100f7.0)') 'Warning:',nconf_dropped,' walkers are dropped that do not have the requested numbers of electrons closest to each atom:', elec_nb_closest_to_atom_input (:)
  endif
  endif ! end l_check_initial_walkers

! Save walkers (and duplicate walkers if necessary):
  do walk_i = 1, nconf
   walk_mod_i = mod(walk_i + idtask*nconf, nconf_read)
   if (walk_mod_i == 0) walk_mod_i = nconf_read
   xoldw (1:ndim,1:nelec,walk_i,1) = coord_elec_wlk_read (:,:,walk_mod_i)
  enddo
  if (nconf_total > nconf_read) then
   nconf_missing = nconf_total - nconf_read
   write(6,'(a,i5,a)') 'Warning: not enough walkers. ', nconf_missing,' remaining walkers duplicated.'
  endif

! mark as valid object xoldw
  call object_modified ('xoldw')

  end subroutine read_initial_walkers

end module walkers_mod
