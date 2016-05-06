-------------------------------------------------------------------------------
-- Title      : TPGPkg
-------------------------------------------------------------------------------
-- File       : TPGPkg.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-15
-- Last update: 2016-05-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package of constants and record definitions for the Timing Geneartor.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;
use work.StdRtlPkg.all;

package TPGPkg is

  constant FIXEDRATEDEPTH : integer := 10;   -- number of fixed rate markers
  constant ACRATEDEPTH    : integer :=  6;   -- number of ac rate markers
  constant MAXALLOWSEQDEPTH: natural :=16;   -- max number of allow sequences
  constant MAXBEAMSEQDEPTH : natural :=16;   -- max number of beam sequences
  constant BEAMSEQWIDTH   : natural := 32;   -- number of bits in beam sequence data
  constant MAXEXPSEQDEPTH : natural := 17;   -- max number of expt sequences
  constant EXPSEQWIDTH    : natural := 32;   -- number of bits in expt sequence
  constant EXPPARTITIONS  : integer :=  8;   -- number of expt partitions
  constant MAXSEQDEPTH    : integer := MAXALLOWSEQDEPTH+MAXBEAMSEQDEPTH+MAXEXPSEQDEPTH;
  constant SEQADDRLEN     : integer := 11;  -- sequencer address bus width
  constant SEQCOUNTDEPTH  : integer := 4;   -- counters within a sequencer (depth of nested loops)
  constant BCSWIDTH       : integer := 1;
  constant MPSDEPTH       : integer := 5;
--  constant MPSWIDTH       : integer := 6;
  constant MAXARRAYSBSA   : integer := 50;
  constant NTRIGGERSIN    : integer := 12;
  constant MPSCHAN        : integer := 14;

  --  Define the ranges of sequence engines by purpose
  constant Allow : slv(MAXALLOWSEQDEPTH-1 downto 0)                    := (others=>'0');
  constant Beam  : slv(Allow'left+MAXBEAMSEQDEPTH downto Allow'left+1) := (others=>'0');
  constant Expt  : slv(Beam'left+MAXEXPSEQDEPTH downto Beam'left+1)    := (others=>'0');
  constant Seq   : slv(Expt'left downto Allow'right)                   := (others=>'0');
  
  type BsaDefType is record
                   nToAvg  : slv(15 downto 0);
                   avgToWr : slv(15 downto 0);
                   rateSel : slv(12 downto 0);
                   -- Bits(12:11)=(fixed,AC,seq,reserved)
                   -- fixed:  marker = 3:0
                   -- AC   :  marker = 2:0;  TS = 8:3 (mask)
                   -- seq  :  bit    = 5:0;  seq = 10:6
                   destSel : slv(18 downto 0);
                   -- Bits(17:16)=(Beam,NoBeam,DONT_CARE,reserved)
                   -- Bits(15:0)=Mask of Destinations (when Beam)
                   init    : sl;
                 end record;
  constant BSADEF_INIT_C : BsaDefType := (
    nToAvg   => (others=>'0'),
    avgToWr  => (others=>'0'),
    rateSel  => (others=>'0'),
    destSel  => (others=>'0'),
    init     => '0');
  
  type BsaDefArray is array(natural range<>) of BsaDefType;

  --  Address into BRAM for sequence engines
  type SeqAddrType is array(SEQADDRLEN-1 downto 0) of sl;
  type SeqAddrArray is array(natural range<>) of SeqAddrType;
  
  type L1TrigConfig is record
                         evcode : slv(7 downto 0);
                         delay  : slv(31 downto 0);
                       end record;
  
  constant L1TRIGCONFIG_INIT_C : L1TrigConfig := (
    evcode => (others=>'1'),
    delay  => (others=>'1') );

  type L1TrigConfigArray  is array (natural range <>) of L1TrigConfig;

  type TPGJumpConfigType is record
                          syncSel  : slv(15 downto 0);
                          syncJump : SeqAddrType;
                          syncClass: slv( 3 downto 0);
                          bcsJump  : SeqAddrType;
                          bcsClass : slv( 3 downto 0);
                          mpsJump  : SeqAddrArray(0 to MPSCHAN-1);
                          mpsClass : Slv4Array   (0 to MPSCHAN-1);
                        end record;
  constant TPG_JUMPCONFIG_INIT_C : TPGJumpConfigType := (
    syncSel   => (others=>'0'),
    syncJump  => (others=>'0'),
    syncClass => (others=>'0'),
    bcsJump   => (others=>'0'),
    bcsClass  => (others=>'0'),
    mpsJump   => (others=>(others=>'0')),
    mpsClass  => (others=>(others=>'0'))
    );


  type TPGJumpConfigArray  is array (natural range <>) of TPGJumpConfigType;

  type SequencerState is record
                              index   : SeqAddrType;
                              count   : Slv8Array(SEQCOUNTDEPTH-1 downto 0);
                            end record;

  type SequencerStateArray  is array (natural range <>) of SequencerState;

  type BeamDiagStatusType is record
    buffers : Slv32Array(3 downto 0);
  end record;
  constant BEAM_DIAG_STATUS_INIT_C : BeamDiagStatusType := (
    buffers => (others=>(others=>'0')) );
  
  type TPGStatusType is record
                          -- implemented resources
                          nbeamseq      : slv (7 downto 0);
                          nexptseq      : slv (7 downto 0);
                          narraysbsa    : slv (7 downto 0);
                          seqaddrlen    : slv (3 downto 0);
                          nallowseq     : slv (3 downto 0);
                          --
                          pulseId       : slv(63 downto 0);
                          timeStamp     : slv(63 downto 0);
                          bsaComplete   : slv(63 downto 0);  -- single sysclk pulse
                          outOfSync     : sl;
                          irqFifoFull   : sl;
                          irqFifoEmpty  : sl;
                          irqFifoData   : slv(31 downto 0);
                          pllChanged    : slv(31 downto 0);
                          count186M     : slv(31 downto 0);
                          countSyncE    : slv(31 downto 0);
                          countBRT      : slv(31 downto 0);
                          countTrig     : Slv32Array(NTRIGGERSIN-1 downto 0);
                          countSeq      : Slv32Array(MAXSEQDEPTH-1 downto 0);
                          countUpdate   : sl;  -- single sysclk pulse
                          beamDiag      : BeamDiagStatusType;
                          rxStatus      : slv(11 downto 0);
                          rxClkCnt      : slv(31 downto 0);
                          rxDVCnt       : slv(31 downto 0);
                          seqRdData     : Slv32Array(MAXSEQDEPTH-1 downto 0);
                          bsaStatus     : Slv32Array(63 downto 0);
                          seqState      : SequencerStateArray(MAXSEQDEPTH-1 downto 0);
                          bcsFault      : slv(BCSWIDTH-1 downto 0);
                        end record;

  constant SEQUENCER_STATE_INIT_C : SequencerState := (
    index   => (others=>'0'),
    count   => (others=>(others=>'0'))
    );
  
  constant TPG_STATUS_INIT_C : TPGStatusType := (
    nbeamseq      => (others=>'0'),
    nexptseq      => (others=>'0'),
    narraysbsa    => (others=>'0'),
    seqaddrlen    => (others=>'0'),
    nallowseq     => (others=>'0'),
    pulseId       => (others=>'0'),
    timeStamp     => (others=>'0'),
    bsaComplete   => (others=>'0'),
    outOfSync     => '0',
    irqFifoFull   => '0',
    irqFifoEmpty  => '0',
    irqFifoData   => (others=>'0'),
    pllChanged    => (others=>'0'),
    count186M     => (others=>'0'),
    countSyncE    => (others=>'0'),
    countBRT      => (others=>'0'),
    countTrig     => (others=>(others=>'0')),
    countSeq      => (others=>(others=>'0')),
    countUpdate   => '0',
    beamDiag      => BEAM_DIAG_STATUS_INIT_C,
    rxStatus      => (others=>'0'),
    rxClkCnt      => (others=>'0'),
    rxDVCnt       => (others=>'0'),
    seqRdData     => (others=>(others=>'0')),
    bsaStatus     => (others=>(others=>'0')),
    seqState      => (others=>SEQUENCER_STATE_INIT_C),
    bcsFault      => (others=>'0') );

  type BeamDiagControlType is record
    manfault   : sl;
    clear      : slv(30 downto 0);
  end record;
  constant BEAM_DIAG_CONTROL_INIT_C : BeamDiagControlType := (
    manfault   => '0',
    clear      => (others=>'0') );
  
  type TPGConfigType is record
                          clock_step      : slv( 4 downto 0);
                          clock_remainder : slv( 4 downto 0);
                          clock_divisor   : slv( 4 downto 0);
                          txPolarity    : sl;
                          baseDivisor   : slv(15 downto 0);
                          pulseId       : slv(63 downto 0);
                          pulseIdWrEn   : sl;
                          timeStamp     : slv(63 downto 0);
                          timeStampWrEn : sl;
                          ACRateDivisors    : Slv8Array(5 downto 0);
                          FixedRateDivisors : Slv20Array(9 downto 0);
                          --
                          SeqRestart    : slv         (63 downto 0);
                          --
                          histActive    : sl;
                          forceSync     : sl;
                          --  Arbiter control
                          seqDestn         : Slv4Array (MAXBEAMSEQDEPTH-1 downto 0);
                          allowRequired    : Slv16Array(MAXBEAMSEQDEPTH-1 downto 0);
                          destnControl     : Slv16Array(MAXBEAMSEQDEPTH-1 downto 0);
                          --
                          irqEnable     : sl;
                          irqFifoEnable : sl;
                          irqIntvEnable : sl;
                          irqBsaEnable  : sl;
                          irqFifoRd     : sl;
                          beamDiag      : BeamDiagControlType;
                          bsadefv       : BsaDefArray(MAXARRAYSBSA-1 downto 0);
                          interval      : slv(31 downto 0);
                          intervalRst   : sl;
                          seqAddr       : SeqAddrType;
                          seqWrData     : slv(31 downto 0);
                          seqWrEn       : slv(MAXSEQDEPTH-1 downto 0);
                          seqJumpConfig : TPGJumpConfigArray(MAXSEQDEPTH-1 downto 0);
                        end record;

  constant TPG_CONFIG_INIT_C : TPGConfigType := (
    clock_step        => "00101",
    clock_remainder   => "00101",
    clock_divisor     => "01101",
    txPolarity        => '0',
    baseDivisor       => x"00C8",
    pulseId           => (others=>'0'),
    pulseIdWrEn       => '1',
    timeStamp         => (others=>'0'),
    timeStampWrEn     => '0',
    ACRateDivisors    => (x"00", x"3C", x"0C", x"06", x"02", x"01"), -- 60,30,10,5,1Hz
    FixedRateDivisors => (x"00000",
                          x"00000",
                          x"F4240", -- 0.93Hz
                          x"186A0", -- 9.29Hz
                          x"02710", -- 92.9Hz
                          x"003E8", -- 929Hz
                          x"00064", -- 9.29kHz
                          x"0000A", -- 92.9kHz
                          x"00005", -- 186kHz
                          x"00001"),-- 929kHz
    SeqRestart        => (others=>'0'),
    histActive        => '1',
    forceSync         => '0',
    seqDestn          => (others=>x"0"),
    allowRequired     => (others=>x"0000"),
    destnControl      => (others=>x"0000"),
    irqEnable         => '0',
    irqFifoEnable     => '0',
    irqIntvEnable     => '0',
    irqBsaEnable      => '0',
    irqFifoRd         => '0',
    beamDiag          => BEAM_DIAG_CONTROL_INIT_C,
    bsadefv           => (others=>BSADEF_INIT_C),
    interval          => x"0000488b",   -- 100 us
    intervalRst       => '1',
    seqAddr           => (others=>'0'),
    seqWrData         => (others=>'0'),
    seqWrEn           => (others=>'0'),
    seqJumpConfig     => (others=>TPG_JUMPCONFIG_INIT_C)
    );

  type TPGConfigArray is array(natural range<>) of TPGConfigType;

  type MpsMessageType is record
    strobe    : sl;
    latchDiag : sl;
    class     : Slv4Array(15 downto 0);
    tag       : slv(15 downto 0);
  end record;
  constant MPS_MESSAGE_INIT_C : MpsMessageType := (
    strobe    => '0',
    latchDiag => '0',
    class     => (others=>(others=>'0')),
    tag       => (others=>'0'));
    
end TPGPkg;

package body TPGPkg is
end package body TPGPkg;
