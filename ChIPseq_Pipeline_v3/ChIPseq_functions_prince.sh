#!/bin/bash
# written by: Tovah Markowitz

# known issues:
# 1) no checks for the following: 
# -- do all SAM files have the same root?
# -- have wiggle files/peak files already been created?
# -- is filemaker ID already in the name? (only works if they are identical)
# 2) memory issue
# 3) three error/output files created at the end of each job

###########################################################
### FUNCTION1

function run_closing {
# run sbatch script ChIPseq_closing.sbatch to organize error/output files
    OUT=$1
    JIDS=$2

    if [[ $JIDS != "" ]]; then
	sbatch --dependency=afterany:$JIDS \
	    --export IDS=$JIDS,OUT=$OUT \
            ~/ChIPseq_Pipeline/ChIPseq_closing.sbatch
    fi
}

###########################################################
### FUNCTION2

function check_fastq {
    # check input variables to determine if they are to be run through Bowtie
    # returns: FQTF as "TRUE/FALSE"
    OUT=$1
    POTFQ=$2
    TAGN=$3
    JIDS=$4

    if [[ $POTFQ =~ .fastq|.fq ]]; then
	if [[ $TAGN == "" ]]; then
	    echo "$POTFQ was not given a tagname" >> $OUT
	    run_closing $OUT $JIDS
	    exit 1
	else
	    FQTF="TRUE"
	fi
    else
	FQTF="FALSE"
    fi
}

###########################################################
### FUNCTION3

function assign_genroot {
    # adjusting output names to fit with genome requested
    # returns: GENROOT and GENROOT2
    OUT=$1
    GEN=$2
    JIDS=$3

    case $GEN in
        SK1 ) GENROOT="SK1K-PM_B3"
	      GENROOT2="SK1K-rDNA_B3"
            ;;
        SacCer3 ) GENROOT="SacCer3-2mis_B3"
	          GENROOT2="SacCer3-2mis-rDNA_B3"
            ;;
        * ) echo "Unknown genome listed." >> $OUT
            run_closing $OUT $JIDS
            exit 1
    esac
}

###########################################################
### FUNCTION4

function parse_inCHIPname {
    OUT=$1
    TREATMENT1=$2
    JIDS=$3

    # if there are spaces in CHIP, it must be replicates
    # continue to parse first file for ROOT
    RESPACE="(^[^[:space:]]*)[[:space:]].*"
    if [[ $TREATMENT1 =~ $RESPACE ]]; then
        TREATMENT=${BASH_REMATCH[1]}
    else
        TREATMENT=$TREATMENT1
    fi

    # parse filename of first ChIP file
    if [[ $TREATMENT == */* ]]; then
        RE='.*/(.+)-(S.+).(sam|bam)'
    else
        RE='(.+)-(S.+).(sam|bam)'
    fi
    if [[ $TREATMENT =~ $RE ]]; then
        TAGC=${BASH_REMATCH[1]}
        GENROOT=${BASH_REMATCH[2]}
    else
        echo "Error: ChIP filename ($TREATMENT) is incorrect." >> $OUT
        echo "Either it is not labelled as a .sam or .bam " >> $OUT
        echo "or it is not in the correct format for this command." >> $OUT
        echo "Correct pattern is (.+)-(S.+).(sam|bam)." >> $OUT
        echo "Make sure the file has one and only one -S." >> $OUT
        echo "Both relative and complete paths are accepted." >> $OUT
        run_closing $OUT $JIDS
        exit 1
    fi
}

###########################################################
### FUNCTION5

function change_genroot {
    # adjust genroot for MACS2
    # create ROOTF (for the files) and ROOTFR (for the outer folder)
    ROOT=$1

if [[ $ROOT =~ "B3"$ ]]; then
    ROOTF=$ROOT
    VER="-B3"
elif [[ $ROOT =~ "2mis-PM" ]]; then
    ROOTF="SacCer3-2mis_"
else
    ROOTF="${ROOT}_"
fi

if [[ $ROOT =~ "SK1K" ]]; then 
    ROOTFR="SK1K$VER"
elif [[ $ROOT =~ "SacCer3" ]]; then
    ROOTFR="SacCer3$VER"
fi
}

###########################################################
### FUNCTION6

function define_MACS2_filenames {
    IN=$1
    ROOTF=$2
    ROOTFR=$3
    TYPE=$4
    FLMKR=$5

    if [[ $FLMKR != "" ]]; then
	if [[ ! $IN =~ $FLMKR ]]; then
	    FLMKR2="-$FLMKR"
	fi
    fi

    TP2=""
    if [[ $TYPE == "NORMAL" ]]; then
	TP2=""
    elif [[ $TYPE =~ "REPS" ]]; then
	TP2="-Reps"
    fi

    if [[ $TYPE =~ "TAGNORM" ]]; then
	M2FILE1=$IN$FLMKR2$TP2-ChvCh-${ROOTF}W3
	M2FILE2=$IN$FLMKR2$TP2-InvIn-${ROOTF}W3
	FOLDER=$IN$FLMKR2$TP2-${ROOTFR}W3
    else
	M2FILE=$IN$FLMKR2$TP2-${ROOTF}W3
	FOLDER=$IN$FLMKR2$TP2-${ROOTFR}W3
    fi
}
