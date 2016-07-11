-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : TimingRx.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-03
-- Last update: 2016-07-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--   Common module to parse both LCLS-I and LCLS-II timing streams.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;

entity TimingRx is
   generic (
      TPD_G               : time            := 1 ns;
      TIMING_MODE_G       : boolean         := true;
      AXIL_ERROR_RESP_G   : slv(1 downto 0) := AXI_RESP_OK_C);
   port (
      rxClk               : in  sl;
      rxRstDone           : in  sl;
      rxData              : in  TimingRxType;

      rxPolarity          : out sl;
      rxReset             : out sl;
      timingClkSel        : out sl; -- '0'=LCLS1, '1'=LCLS2
      timingClkSelR       : out sl; 
      
      timingStream        : out TimingStreamType;
      timingStreamStrobe  : out sl;
      timingStreamValid   : out sl;
      
      timingMessage       : out TimingMessageType;
      timingMessageStrobe : out sl;
      timingMessageValid  : out sl;

      exptMessage         : out ExptMessageType;
      exptMessageValid    : out sl;
      
      txClk               : in  sl;

      axilClk             : in  sl;
      axilRst             : in  sl;
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType
      );

end entity TimingRx;

architecture rtl of TimingRx is

   -------------------------------------------------------------------------------------------------
   -- axilClk Domain
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      clkSel         : sl;
      cntRst         : sl;
      rxPolarity     : sl;
      rxReset        : sl;
      messageDelay   : slv(19 downto 0);
      messageDelayRst: sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record AxilRegType;

   constant AXIL_REG_INIT_C : AxilRegType := (
      clkSel         => ite(TIMING_MODE_G,'1','0'),
      cntRst         => '0',
      rxPolarity     => '0',
      rxReset        => '0',
      messageDelay   => (others=>'0'),
      messageDelayRst=> '1',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;

   signal staData            : Slv4Array(1 downto 0);
   
   signal rxDecErrSum        : sl;
   signal rxDspErrSum        : sl;

   signal rxClkCnt           : slv(3 downto 0) := (others=>'0');
   signal stv                : slv(3 downto 0);
   signal axilRxLinkUp       : sl;
   signal axilStatusCounters1,
          axilStatusCounters2,
          axilStatusCounters12,
          axilStatusCounters3 : SlVectorArray(3 downto 0, 31 downto 0);
   signal txClkCnt            : slv( 3 downto 0) := (others=>'0');
   signal txClkCntS           : slv(31 downto 0);
   signal rxRst               : slv( 1 downto 0);
   signal clkSelR             : sl;
   signal messageDelayR       : slv(19 downto 0);
   signal messageDelayRst     : sl;
begin

   U_RxLcls1 : entity work.TimingStreamRx
       generic map (
         TPD_G             => TPD_G,
         AXIL_ERROR_RESP_G => AXI_RESP_DECERR_C)
       port map (
         rxClk               => rxClk,
         rxRst               => rxRst(0),
         rxData              => rxData,
         timingMessage       => timingStream,
         timingMessageStrobe => timingStreamStrobe,
         timingMessageValid  => timingStreamValid,
         staData             => staData(0) );

   U_RxLcls2 : entity work.TimingFrameRx
       generic map (
         TPD_G             => TPD_G,
         AXIL_ERROR_RESP_G => AXI_RESP_DECERR_C )
       port map (
         rxClk               => rxClk,
         rxRst               => rxRst(1),
         rxData              => rxData,
         messageDelay        => messageDelayR,
         messageDelayRst     => messageDelayRst,
         timingMessage       => timingMessage,
         timingMessageStrobe => timingMessageStrobe,
         exptMessage         => exptMessage,
         exptMessageValid    => exptMessageValid,
         staData             => staData(1) );
     
   axilComb : process (axilR, axilReadMaster, axilRst,
                       axilRxLinkUp,
                       axilStatusCounters12,
                       axilStatusCounters3,
                       axilWriteMaster, txClkCntS) is
      variable v          : AxilRegType;
      variable axilStatus : AxiLiteStatusType;

      -- Wrapper procedures to make calls cleaner.
      procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv; cA : in boolean := false; cV : in slv := "0") is
      begin
         axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg, cA, cV);
      end procedure;

      procedure axilSlaveRegisterR (addr : in slv; offset : in integer; reg : in slv) is
      begin
         axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, offset, reg);
      end procedure;

      procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
      begin
         axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
      end procedure;

      procedure axilSlaveRegisterR (addr : in slv; offset : in integer; reg : in sl) is
      begin
         axiSlaveRegister(axilReadMaster, v.axilReadSlave, axilStatus, addr, offset, reg);
      end procedure;

      procedure axilSlaveDefault (
         axilResp : in slv(1 downto 0)) is
      begin
         axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, axilResp);
      end procedure;

   begin
      -- Latch the current value
      v := axilR;
      v.axilReadSlave.rdata := (others=>'0');

      -- Determine the transaction type
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      -- Status Counters
      axilSlaveRegisterR(X"00", 0, muxSlVectorArray(axilStatusCounters12, 0));
      axilSlaveRegisterR(X"04", 0, muxSlVectorArray(axilStatusCounters12, 1));
      axilSlaveRegisterR(X"08", 0, muxSlVectorArray(axilStatusCounters12, 2));
      axilSlaveRegisterR(X"0C", 0, muxSlVectorArray(axilStatusCounters12, 3));
      axilSlaveRegisterR(X"10", 0, muxSlVectorArray(axilStatusCounters3, 0));
      axilSlaveRegisterR(X"14", 0, muxSlVectorArray(axilStatusCounters3, 1));
      axilSlaveRegisterR(X"18", 0, muxSlVectorArray(axilStatusCounters3, 2));
      axilSlaveRegisterR(X"1C", 0, muxSlVectorArray(axilStatusCounters3, 3));

      axilSlaveRegisterW(X"20", 0, v.cntRst);
      axilSlaveRegisterR(X"20", 1, axilRxLinkUp);
      axilSlaveRegisterW(X"20", 2, v.rxPolarity);
      axilSlaveRegisterW(X"20", 3, v.rxReset);
      axilSlaveRegisterW(X"20", 4, v.clkSel);

      axilSlaveRegisterW(X"24", 0, v.messageDelay);
      axilSlaveRegisterR(X"28", 0, txClkCntS);

      axilSlaveDefault(AXIL_ERROR_RESP_G);

      v.messageDelayRst := '0';
      if (axilStatus.writeEnable='1' and
          std_match(axilWriteMaster.awaddr(7 downto 0),x"24")) then
        v.messageDelayRst := '1';
      end if;

      --if (axilRst = '1') then
      --   v := AXIL_REG_INIT_C;
      --end if;

      axilRin <= v;

      rxPolarity     <= axilR.rxPolarity;
      rxReset        <= axilR.rxReset;
      axilReadSlave  <= axilR.axilReadSlave;
      axilWriteSlave <= axilR.axilWriteSlave;

   end process;

   axilSeq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process;

   txClkCnt_seq : process (txClk) is
   begin
     if rising_edge(txClk) then
       txClkCnt <= txClkCnt+1;
     end if;
   end process txClkCnt_seq;
   
   SynchronizerOneShotCnt_1 : entity work.SynchronizerOneShotCnt
     generic map (
       TPD_G          => TPD_G,
       CNT_RST_EDGE_G => true,
       CNT_WIDTH_G    => 32 )
     port map (
       dataIn       => txClkCnt(txClkCnt'left),
       rollOverEn   => '1',
       cntRst       => axilR.cntRst,
       dataOut      => open,
       cntOut       => txClkCntS,
       wrClk        => txClk,
       wrRst        => '0',
       rdClk        => axilClk,
       rdRst        => axilRst );

   axilRxLinkUp <= stv(1);
   axilStatusCounters12 <= axilStatusCounters1 when axilR.clkSel='0' else
                           axilStatusCounters2;
   rxDecErrSum  <= rxData.decErr(0) or rxData.decErr(1);
   rxDspErrSum  <= rxData.dspErr(0) or rxData.dspErr(1);

   SyncStatusVector_1 : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => "1111",
         USE_DSP48_G    => "no",
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 32,
         WIDTH_G        => 4 )
      port map (
         statusIn(3 downto 0)  => staData(0),
         cntRstIn       => axilR.cntRst,
         rollOverEnIn => "0111",
         cntOut       => axilStatusCounters1,
         wrClk        => rxClk,
         wrRst        => '0',
         rdClk        => axilClk,
         rdRst        => '0');

   SyncStatusVector_2 : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => "1111",
         USE_DSP48_G    => "no",
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 32,
         WIDTH_G        => 4 )
      port map (
         statusIn(3 downto 0)  => staData(1),
         cntRstIn     => axilR.cntRst,
         rollOverEnIn => "0111",
         cntOut       => axilStatusCounters2,
         wrClk        => rxClk,
         wrRst        => '0',
         rdClk        => axilClk,
         rdRst        => '0');

   SyncStatusVector_3 : entity work.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         IN_POLARITY_G  => "1111",
         USE_DSP48_G    => "no",
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => 32,
         WIDTH_G        => 4 )
      port map (
         statusIn(0)  => rxClkCnt(rxClkCnt'left),
         statusIn(1)  => rxRstDone,
         statusIn(2)  => rxDecErrSum,
         statusIn(3)  => rxDspErrSum,
         statusOut    => stv,
         cntRstIn     => axilR.cntRst,
         rollOverEnIn => "0001",
         cntOut       => axilStatusCounters3,
         wrClk        => rxClk,
         wrRst        => '0',
         rdClk        => axilClk,
         rdRst        => '0');

   rxClkCnt_seq : process (rxClk) is
   begin
      if (rising_edge(rxClk)) then
         rxClkCnt <= rxClkCnt+1;
      end if;
   end process rxClkCnt_seq;

   SyncRxRst : entity work.Synchronizer
     port map ( clk     => rxClk,
                dataIn  => axilR.clkSel,
                dataOut => clkSelR );

   SyncDelayRst : entity work.Synchronizer
     port map ( clk     => rxClk,
                dataIn  => axilR.messageDelayRst,
                dataOut => messageDelayRst );

   SyncDelay : entity work.SynchronizerVector
     generic map ( WIDTH_G => axilR.messageDelay'length )
     port map ( clk     => rxClk,
                dataIn  => axilR.messageDelay,
                dataOut => messageDelayR );
   
   rxRst(0)      <= '1' when (rxRstDone='0' or clkSelR='1') else '0';
   rxRst(1)      <= '1' when (rxRstDone='0' or clkSelR='0') else '0';
   timingClkSel  <= axilR.clkSel;
   timingClkSelR <= clkSelR;
   
end architecture rtl;
