#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Timing trigger pulse comfiguration
#-----------------------------------------------------------------------------
# File       : LclsTriggerPulse.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Timing trigger pulse comfiguration
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class LclsTriggerPulse(pr.Device):
    def __init__(self, name="LclsTriggerPulse", description="Timing trigger pulse comfiguration", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(8):
            self.add(pr.Variable(   name         = "OpCodeMask_%i" % (i),
                                    description  = "Opcode mask 256 bits to connect the pulse to any combination of opcodes %i" % (i),
                                    offset       =  0x00 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        self.add(pr.Variable(   name         = "PulseDelay",
                                description  = "Pulse delay (Number of recovered clock cycles)",
                                offset       =  0x20,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "PulseWidth",
                                description  = "Pulse Width (Number of recovered clock cycles)",
                                offset       =  0x24,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "PulsePolarity",
                                description  = "Pulse polarity: 0-Normal. 1-Inverted",
                                offset       =  0x28,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))
