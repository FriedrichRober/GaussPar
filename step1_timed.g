ClearDown := function( f, H, t, R )
    local tmp, Chi, ct, HH, tt, RR, ttt, RRR, i, RRn, A, AA, T, M, K, E, s, u;

    if  IsEmpty(H) then
        return [R,t, [ [],[],[],[],[],[] ] ];
    fi;

    #### INITIALIZATION ####
    ## Residue R was empty. Thus matrix above has full column-rank.
    if not IsEmpty(t) and IsEmpty( R ) then
        A := H;
        M := [];
        E := [];
        K := [];
        s := [];
        RR := [];
        tt := [];
        ttt := t;
        u := 0 * t;
        T:=[A, M, E, K, s, u];
        return [RR, ttt, T];
    fi;

    ## First step (i=1,  i block row) or all matrices above have rank 0
    if IsEmpty( t ) then
        # A is empty iff this case happens, Q is empty then aswell
        A := [];
        HH := H;
    else
        # Column Extraction
        tmp := CEX( f, BitstringToCharFct(t), H );
        A := ImmutableMatrix(f,tmp[1]); AA := ImmutableMatrix(f,tmp[2]);
        # Reduce H to (0|HH)
        # Mult Add
        if IsEmpty(A) then
            HH := AA;
        else
            HH := AA + A*R;
        fi;
    fi;
 
 
    #### END INITIALIZATION ####

    # Echelonization
    tmp := ECH( f, HH );
    M:=ImmutableMatrix(f,tmp[1]);
    K:=ImmutableMatrix(f,tmp[2]);
    RR:=ImmutableMatrix(f,tmp[3]);
    s:=tmp[4];tt:=tmp[5];
    #Error( "Break Point - echel" );

    # TODO complement then extend?
    if IsEmpty(t) then Chi := tt;
    else
     Chi := 0*[1..DimensionsMat(H)[2]];ct:=1;
     if not tt=[] then
        for i in [1..Length(Chi)] do
            if t[i]=0 then
                if tt[ct]=1 then Chi[i] := 1; fi;
                ct:= ct+1;
            fi;
        od;
     fi;
    fi;

    ## Are we running into any special cases, where return values
    ## of the above echelonization are empty?
    # The case K empty is handled by UpdateRow.
    #
    # The following are equivalent:
    # s is empty
    # tt is empty
    # M is empty
    #
    # This only happens when A*R + AA = 0
    if ForAny( [ M, s, tt ], IsEmpty ) then
        M := [];
        E := [];
        K := [];
        s := [];
        RR := R; # Residue does not change
        ttt := t;
        u := 0 * t;
        T:=[ImmutableMatrix(f,A), M, E, K, s, u];
        return [RR, ttt, T];
    fi;
    # If RR is empty, but tt is not, then the bitstring tt, representing
    # the positions of the new pivot columns, is AllOne.
    # In this case, there is nothing to be done here.

    #Error( "Break Point - before CEX new residue" );
    tmp := CEX( f, BitstringToCharFct(tt), R );
    E:=ImmutableMatrix(f,tmp[1]);
    RRn:=ImmutableMatrix(f,tmp[2]);
    ## Update the residue and the pivot column bitstring
    tmp := PVC( BitstringToCharFct(t), BitstringToCharFct(Chi) );
    ttt:=CharFctToBitstring(DimensionsMat(H)[2], tmp[1]); u:=tmp[2];
    # Error( "Break Point - after CEX new residue" );
    
    T:=[ImmutableMatrix(f,A), ImmutableMatrix(f,M), ImmutableMatrix(f,E), ImmutableMatrix(f,K), s, u];

    ## Did column extraction return empty values?
    if IsEmpty(E) then ## if the above was all zero but we got new pivots in the current iteration
        return [RR, ttt, T];
    fi;

    ## RRn is empty, iff. the new pivot columns completely
    ## annihilate the old residue.
    if IsEmpty(RRn) then
        RR := [];
    else
        if IsEmpty(RR) then
            RR := RRn;
        else
            RRR:=RRn+E*RR;
            RR := RRF( RRR, RR, u );
        fi;
    fi;

    return [RR, ttt, T];
end;

UpdateRow := function( f, T, H, Bjk )
 local A, E, M, K, s, u,  tmp, Z, V, X, W, S, B;

 B := Bjk;
 A:=T[1];M:=T[2];E:=T[3];K:=T[4];s:=T[5];u:=T[6];
 
 ###
 # If A is empty, there are no rowoperations form above to consider
 ###
 if IsEmpty(A) or IsEmpty(B) then
  Z := H;
 else
  Z := A*B+H;
 fi;

 tmp := REX( f, BitstringToCharFct(s), Z );
 V:=ImmutableMatrix(f,tmp[1]);
 W:=ImmutableMatrix(f,tmp[2]);
 ###
 # If V is empty, then there where no operations exept from A
 # in this case there is nothing more to update
 ###
 if IsEmpty(V) or IsEmpty(M) then
  return [Z,B]; 
 else 
  X:=M*V;
 fi;

 if IsEmpty(E) then
     S := B;
 else
     S:= E*X+B;
 fi;
 B:=RRF( S, X, u );
 
 ###
 # if K is empty, then s is the all-one-bitstring and there are no non-pivot rows
 # which would change according to K. So K should be empty and there is nothing more to update
 ###
 if not IsEmpty(K) then
  # s is neither empty nor all-one at this point
  H := K*V+W;
 else
  H := W;
 fi;
 
 return [H, B];
end;

Step1_timed:= function( A, n )
    local f, C, B, Rj, tj,TIMES_CLEARDOWN,TIMES_UPDATEROW,
        dummyTask, TaskListClearDown, TaskListUpdateRow,
        i, j, k, first;
    first := IO_gettimeofday().tv_sec;
    Print(0,"\n");
    ## Chop A into an nxn matrix
    f := DefaultFieldOfMatrix( A );
    Print(first - IO_gettimeofday().tv_sec,"\n");
    C := ChoppedMatrix( A,n,n );
    Print("chop: ",first - IO_gettimeofday().tv_sec,"\n");
    # FIXME UNUSED CODE
    ## Initialize B as an nxn list pointing to empty lists
    B := List( [1..n], x -> List( [1..n], x -> [] ) );
    Rj := [];
    tj := [];
    ########## Keep track of Tasks ##########
    dummyTask := RunTask( function() return rec( result := [ [],[] ],time := 0); end );
    ## TODO Do we need to erase the TaskResults manually?
    ## nxn many tasks
    TaskListClearDown := List(
        [1..n],
        x -> List( [1..n], x -> dummyTask )
    );
    TIMES_CLEARDOWN := List(
        [1..n],
        x -> List( [1..n], x -> dummyTask )
    );
    ## nxnxn many tasks
    TaskListUpdateRow := List(
        [1..n],
        x -> List(
            [1..n],
            x -> List( [1..n], x -> dummyTask )
        )
    );
    TIMES_UPDATEROW := List(
        [1..n],
        x -> List(
            [1..n],
            x -> List( [1..n], x -> dummyTask )
        )
    );
    for  i in [ 1 .. n ] do
        TIMES_CLEARDOWN[i][1] := 0;    
    od;
    Print("init: ",first - IO_gettimeofday().tv_sec,"\n");

    for i in [ 1 .. n ] do
        for j in [ 1 .. n ] do
            ########## Schedule ClearDown Tasks ##########
            ## first row, first column: start computation
            if i = 1 and j = 1 then
                TaskListClearDown[i][j] := RunTask( GET_REAL_TIME_OF_FUNCTION_CALL,
                                                    ClearDown,
                                                    [f, C[i][j], [], []],
                                                    rec( passResult := true )
                                           );
    
            ## first row: wait for left-side `UpdateRow`s
            elif i = 1 and j > 1 then
                TaskListClearDown[i][j] := ScheduleTask(
                    ## Condition
                    TaskListUpdateRow[i][j-1][j],
                    ## Function Call
                    GET_REAL_TIME_OF_FUNCTION_CALL,
                    ClearDown,
                    [f,
                    TaskResult( TaskListUpdateRow[i][j-1][j] ).result[1],
                    [],
                    []],
                    rec( passResult := true )  

                );

            ## first column: wait for upper `ClearDown`s
            elif i > 1 and j = 1 then
                TaskListClearDown[i][j] := ScheduleTask(
                    ## Condition
                    TaskListClearDown[i-1][j],
                    ## Function Call
                    GET_REAL_TIME_OF_FUNCTION_CALL,
                    ClearDown,
                    [f,
                    C[i][j],
                    TaskResult( TaskListClearDown[i-1][j] ).result[2],
                    TaskResult( TaskListClearDown[i-1][j] ).result[1]],
                    rec( passResult := true )
                );

            else ## i > 1, j > 1: wait for "everything"
                TaskListClearDown[i][j] := ScheduleTask(
                    ## Condition: List of tasks to wait on
                    [ TaskListClearDown[i-1][j],
                      TaskListUpdateRow[i][j-1][j] ],
                    ## Function Call
                    GET_REAL_TIME_OF_FUNCTION_CALL,
                    ClearDown,
                    [f,
                    TaskResult( TaskListUpdateRow[i][j-1][j] ).result[1],
                    TaskResult( TaskListClearDown[i-1][j] ).result[2],
                    TaskResult( TaskListClearDown[i-1][j] ).result[1]],
                    rec( passResult := true )
                );
            fi;
            ########## Schedule UpdateRow Tasks ##########
            for k in [ j+1 .. n ] do
                ## first row: since j = 2 no previous UpdateRow was spawned
                if i = 1 and j = 1 then
                    TaskListUpdateRow[i][j][k] := ScheduleTask(
                        ## Condition: List of tasks to wait on
                        [ TaskListClearDown[i][j] ],
                        ## Function Call
                        GET_REAL_TIME_OF_FUNCTION_CALL,
                        UpdateRow,
                        [f,
                        TaskResult( TaskListClearDown[i][j] ).result[3],
                        C[i][k],
                        []],
                        rec( passResult := true )
                    );
                   
                ## first row: wait
                elif i = 1 and j > 1 then
                    TaskListUpdateRow[i][j][k] := ScheduleTask(
                        ## Condition: List of tasks to wait on
                        [ TaskListClearDown[i][j],
                          TaskListUpdateRow[i][j-1][k] ],
                        ## Function Call
                        GET_REAL_TIME_OF_FUNCTION_CALL,
                        UpdateRow,
                        [f,
                        TaskResult( TaskListClearDown[i][j] ).result[3],
                        TaskResult( TaskListUpdateRow[i][j-1][k] ).result[1],
                        []],
                        rec( passResult := true )
                    );
                    
                elif i > 1 and j = 1 then
                    TaskListUpdateRow[i][j][k] := ScheduleTask(
                        ## Condition: List of tasks to wait on
                        [ TaskListClearDown[i][j],
                          TaskListUpdateRow[i-1][j][k] ],
                        ## Function Call
                        GET_REAL_TIME_OF_FUNCTION_CALL,
                        UpdateRow,
                        [f,
                        TaskResult( TaskListClearDown[i][j] ).result[3],
                        C[i][k],
                        TaskResult( TaskListUpdateRow[i-1][j][k] ).result[2]],
                        rec( passResult  := true )
                    );
                
		else ## i > 1 and j > 1
                    TaskListUpdateRow[i][j][k] := ScheduleTask(
                        ## Condition: List of tasks to wait on
                        [ TaskListClearDown[i][j],
                          TaskListUpdateRow[i][j-1][k],
                          TaskListUpdateRow[i-1][j][k] ],
                        ## Function Call
                        GET_REAL_TIME_OF_FUNCTION_CALL,
                        UpdateRow,
                        [f,
                        TaskResult( TaskListClearDown[i][j] ).result[3],
                        TaskResult( TaskListUpdateRow[i][j-1][k] ).result[1],
                        TaskResult( TaskListUpdateRow[i-1][j][k] ).result[2]],
                        rec( passResult := true )
                    );
                fi;
            od;
        od;
    od;

    Print("schedule: ",first - IO_gettimeofday().tv_sec,"\n");
    ## DEBUG
    Print( "Tasks succesfully scheduled\n" );

    ## TODO V is that so? V
    ## This is implicitly waiting on all UpdateRow calls
    WaitTask( Concatenation( TaskListClearDown ) );
    WaitTask( Concatenation( List( TaskListUpdateRow, Concatenation ) ) );
    tj := List( [ 1..n ], j -> TaskResult( TaskListClearDown[n][j] ).result[2] );
    Rj := List( [ 1..n ], j -> TaskResult( TaskListClearDown[n][j] ).result[1] );
   
    B := List( [ 1..n ], j -> List( [ 1..n ], k -> TaskResult( TaskListUpdateRow[n][j][k] ).result[2] ) );
    TIMES_UPDATEROW := List( [ 1..n ], j -> List( [ 1..n ], k -> TaskResult( TaskListUpdateRow[n][j][k] ).time ) );
    for i in [ 1 .. n ] do
        for j in [ 2 .. n ] do
            C[i][j] := TaskResult(TaskListUpdateRow[i][j-1][j]).result[1];
            TIMES_CLEARDOWN[i][j] := TaskResult(TaskListUpdateRow[i][j-1][j]).time;
        od;
        TIMES_CLEARDOWN[i][1] := TaskResult(TaskListClearDown[i][1]).time;
    od;

    #Error( "Break Point - END OF STEP1" );
    Print("waiting: ",first - IO_gettimeofday().tv_sec,"\n");
    return rec( result := [ C, B, Rj, tj ], times := [TIMES_UPDATEROW,TIMES_CLEARDOWN]);
end;
