module current_mapping
contains 

subroutine current_node_patch_mapping(chara,curr,msh)
    
    use MODULE_FILE
    implicit none
    
    integer patch, edge, node_patch(3), node_edge, node
    integer i,j,k,ii,jj,kk,flag
    real*8 center(3), current_patch(3,0:3),  current_abs, r, a
    character chara
    character(20) string 
    complex(kind=8)::curr(:)
	type(mesh)::msh
	
    real*8,allocatable :: current_at_patch(:), current_at_node(:)
    integer,allocatable :: edge_of_patch(:,:)
    
    allocate (edge_of_patch(3,msh%maxpatch))
    edge_of_patch = -1
	allocate (current_at_node(msh%maxnode),current_at_patch(msh%maxpatch))
    
    !$omp parallel do default(shared) private(patch,i,edge)
    do patch=1,msh%maxpatch
        i=0
        ! do while (i<3)     !!! Modified by Yang Liu, commented out, this doesn't make sense
            do edge=1, msh%Nunk            
                if (msh%info_unk(3,edge)==patch .or. msh%info_unk(4,edge)==patch) then
                    i=i+1
                    edge_of_patch(i,patch)=edge
                endif
            enddo
        ! enddo                
    enddo
    !$omp end parallel do
    
    !$omp parallel do default(shared) private(patch,i,j,edge,current_abs,current_patch,a,r)
    do patch=1, msh%maxpatch
        do i=1,3
            center(i)=1./3.*(msh%xyz(i,msh%node_of_patch(1,patch))+msh%xyz(i,msh%node_of_patch(2,patch))+msh%xyz(i,msh%node_of_patch(3,patch)))
        enddo
        do edge=1,3
			if(edge_of_patch(edge,patch)==-1)then
				current_patch(:,edge)=0
			else 
				current_abs=dble(curr(edge_of_patch(edge,patch)))
				if (msh%info_unk(3,edge_of_patch(edge,patch))==patch) then
					r=0.                
					do j=1,3
						a=msh%xyz(j,msh%info_unk(5,edge_of_patch(edge,patch)))-center(j)
						r=r+a**2
						current_patch(j,edge)=current_abs*a
					enddo
					r=sqrt(r)
					do j=1,3
						current_patch(j,edge)=current_patch(j,edge)/r
					enddo
				elseif (msh%info_unk(4,edge_of_patch(edge,patch))==patch) then
					r=0.                
					do j=1,3
						a=msh%xyz(j,msh%info_unk(6,edge_of_patch(edge,patch)))-center(j)
						r=r+a**2
						current_patch(j,edge)=-current_abs*a
					enddo
					r=sqrt(r)
					do j=1,3
						current_patch(j,edge)=current_patch(j,edge)/r
					enddo
				endif
			endif	
        enddo
        do i=1,3
            current_patch(i,0)=0.
            do edge=1,3
                current_patch(i,0)=current_patch(i,0)+current_patch(i,edge)
            enddo
        enddo
        current_at_patch(patch)=sqrt(current_patch(1,0)**2+current_patch(2,0)**2+current_patch(3,0)**2)
    enddo
    !$omp end parallel do
    
    !$omp parallel do default(shared) private(patch,i,ii,node,a)
    do node=1, msh%maxnode
        ii=0; a=0.
        do patch=1, msh%maxpatch
            do i=1,3
                if (msh%node_of_patch(i,patch)==node) then
                    a=a+current_at_patch(patch)
                    ii=ii+1
                endif
            enddo
        enddo
        current_at_node(node)=a/dble(ii)
    enddo
    !$omp end parallel do
    
    string='current'//chara//'.out'
    open(30,file=string)
    do node=1, msh%maxnode
        write (30,*) node,current_at_node(node)
    enddo
    close(30)
    
    deallocate (edge_of_patch,current_at_node,current_at_patch)
    return
    
end subroutine current_node_patch_mapping
end module current_mapping    
    
        
        