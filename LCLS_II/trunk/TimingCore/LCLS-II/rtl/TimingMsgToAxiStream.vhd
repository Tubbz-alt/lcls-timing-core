-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TimingMsgToAxiStream.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Convert timing messages into an (SSI) AxiStream
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.TimingPkg.all;

entity TimingMsgToAxiStream is

   generic (
      TPD_G          : time                := 1 ns;
      COMMON_CLOCK_G : boolean             := false;  -- Set true if timingClk=axisClk
      SHIFT_SIZE_G   : integer range 16 to 128;
      AXIS_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(8, TKEEP_NORMAL_C));

   port (
      timingClk       : in sl;
      timingRst       : in sl;
      timingMsg       : in TimingMsgType;
      timingMsgStrobe : in sl;

      axisClk    : in  sl;
      axisRst    : in  sl;
      axisMaster : out AxiStreamMasterType;
      axisSlave  : in  AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C);

end entity TimingMsgToAxiStream;

architecture rtl of TimingMsgToAxiStream is

   -------------------------------------------------------------------------------------------------
   -- timingClk Domain
   -------------------------------------------------------------------------------------------------
   constant INT_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(SHIFT_SIZE_G/8, AXIS_CONFIG_G.TKEEP_MODE_C);
   constant SHIFT_COUNT_MAX_C : integer             := TIMING_MSG_BITS_C/SHIFT_SIZE_C;
   constant COUNT_SIZE_C      : integer             := bitSize(SHIFT_COUNT_MAX_C);

   constant

      type RegType is record
      ssiMaster : SsiMasterType;
      msg       : slv(TIMING_MSG_BITS_C-1 downto 0);
      active    : sl;
      count     : slv(COUNT_SIZE_C-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      ssiMaster => ssiMasterInit(INT_AXIS_CONFIG_C),
      msg       => (others => '0'),
      active    => '0',
      count     => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal timingAxisMaster : AxiStreamMasterType;

begin

   comb : process (r, timingMsg, timingMsgStrobe, timingRst) is
      variable v : RegType;
   begin
      v := r;

      v.count := (others => '0');

      if (timingMsgStrobe = '1') then
         v.msg := toSlv(timingMsg);
         v.active = '1';
      end if;

      v.ssiMaster     := ssiMasterInit(INT_AXIS_CONFIG_C);
      v.ssiMaster.sof := ite(r.count = 0, '1', '0');
      v.ssiMaster.eof := ite(r.count = SHIFT_COUNT_MAX_C, '1', '0');

      if (r.active = '1') then
         v.ssiMaster.data(SHIFT_SIZE_C-1 downto 0) := r.msg(SHIFT_SIZE_C-1 downto 0);

         v.ssiMaster.valid := '1';
         v.active          := ite(v.ssiMaster.eof = '1', '0', '1');
         v.msg             := slvZero(SHIFT_SIZE_C) & r.msg(TIMING_MSG_BITS_C-1 downto SHIFT_SIZE_C);
      end if;


      if (timingRst = '1') then
         v := REG_INIT_C;
      end if;

      timingAxisMaster <= ssi2AxisMaster(r.ssiMaster, INT_AXIS_CONFIG_C);

      rin <= v;

   end process comb;

   seq : process (timingClk) is
   begin
      if (rising_edge(timingClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   AxiStreamFifo_1 : entity work.AxiStreamFifo
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_CLOCK_G,
         FIFO_ADDR_WIDTH_G   => 4,
         FIFO_FIXED_THRESH_G => true,
--         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         SLAVE_AXI_CONFIG_G  => INT_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_G)
      port map (
         sAxisClk    => timingClk,
         sAxisRst    => timingRst,
         sAxisMaster => timingAxisMaster,
         sAxisSlave  => open,
         sAxisCtrl   => open,
         mAxisClk    => axisClk,
         mAxisRst    => axisRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);

end architecture rtl;

