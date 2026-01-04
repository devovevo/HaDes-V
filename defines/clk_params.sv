/* Copyright (c) 2024 Tobias Scheipel, David Beikircher, Florian Riedl
 * Embedded Architectures & Systems Group, Graz University of Technology
 * SPDX-License-Identifier: MIT
 * ---------------------------------------------------------------------
 * File: clk_params.sv
 */

/*verilator lint_off UNUSED*/

package clk_params;

`ifdef BOARD_ZYBO
    // =========================================================================
    // ZYBO Z7 CONFIGURATION (125 MHz Input)
    // =========================================================================
    
    localparam real INPUT_CLK_FREQUENCY_MHZ    = 125.000;
    localparam real INPUT_CLK_JITTER_PS        = 80.000;  // Approx for 125M
    localparam real INPUT_CLK_JITTER_TO_PERIOD = 0.010;   
    localparam real INPUT_CLK_PERIOD_NS        = 8.000;   // 1000 / 125 = 8ns

    // --- System Clock (Target: 50 MHz) ---
    // VCO = 125 * 8 = 1000 MHz (Valid range 600-1200)
    // Out = 1000 / 20 = 50 MHz
    localparam real MMCM_MUL   = 8.000; 
    localparam int  MMCM_DIV   = 1;      
    localparam real MMCM_DIV_0 = 20.000; 

    localparam real SYS_CLK_FREQUENCY_MHZ = (INPUT_CLK_FREQUENCY_MHZ / MMCM_DIV * MMCM_MUL) / MMCM_DIV_0;
    localparam real SYS_CLK_PERIOD_NS     = 1000.000 / SYS_CLK_FREQUENCY_MHZ;

    // --- VGA Clock (Target: ~25.0 MHz) ---
    // PLL1: 125 MHz -> 100 MHz
    // VCO = 125 * 8 = 1000 MHz
    // Out = 1000 / 10 = 100 MHz
    localparam int  PLL1_MUL   = 8; 
    localparam int  PLL1_DIV   = 1; 
    localparam real PLL1_DIV_0 = 10; 

    localparam real PLL1_FREQUENCY_MHZ = (INPUT_CLK_FREQUENCY_MHZ / PLL1_DIV * PLL1_MUL) / PLL1_DIV_0;
    localparam real PLL1_PERIOD_NS     = 1000.000 / PLL1_FREQUENCY_MHZ;

    // PLL2: 100 MHz -> 25 MHz
    // VCO = 100 * 10 = 1000 MHz
    // Out = 1000 / 40 = 25 MHz
    localparam int  PLL2_MUL   = 10; 
    localparam int  PLL2_DIV   = 1;  
    localparam real PLL2_DIV_0 = 40; 

    localparam real PLL2_FREQUENCY_MHZ = (PLL1_FREQUENCY_MHZ / PLL2_DIV * PLL2_MUL) / PLL2_DIV_0;
    localparam real PLL2_PERIOD_NS     = 1000.000 / PLL2_FREQUENCY_MHZ;

    localparam real VGA_CLK_FREQUENCY_MHZ = PLL2_FREQUENCY_MHZ;
    localparam real VGA_CLK_PERIOD_NS     = PLL2_PERIOD_NS;

`else
    // =========================================================================
    // BASYS 3 CONFIGURATION (100 MHz Input) - DEFAULT
    // =========================================================================

    localparam real INPUT_CLK_FREQUENCY_MHZ    =  100.000;
    localparam real INPUT_CLK_JITTER_PS        =   95.000;
    localparam real INPUT_CLK_JITTER_TO_PERIOD =    0.010;  
    localparam real INPUT_CLK_PERIOD_NS        = 1000.000 / INPUT_CLK_FREQUENCY_MHZ;

    // --- System Clock (Target: 50 MHz) ---
    localparam real MMCM_MUL   = 10.000; 
    localparam int  MMCM_DIV   = 1;      
    localparam real MMCM_DIV_0 = 20.000; 

    localparam real SYS_CLK_FREQUENCY_MHZ = (INPUT_CLK_FREQUENCY_MHZ / MMCM_DIV * MMCM_MUL) / MMCM_DIV_0;
    localparam real SYS_CLK_PERIOD_NS     = 1000.000 / SYS_CLK_FREQUENCY_MHZ;

    // --- VGA Clock (Target: 25.175 MHz) ---
    localparam int  PLL1_MUL   = 53; 
    localparam int  PLL1_DIV   = 5;  
    localparam real PLL1_DIV_0 = 10; 

    localparam real PLL1_FREQUENCY_MHZ = (INPUT_CLK_FREQUENCY_MHZ / PLL1_DIV * PLL1_MUL) / PLL1_DIV_0;
    localparam real PLL1_PERIOD_NS     = 1000.000 / PLL1_FREQUENCY_MHZ;

    localparam int  PLL2_MUL   = 19; 
    localparam int  PLL2_DIV   = 2;  
    localparam real PLL2_DIV_0 = 40; 

    localparam real PLL2_FREQUENCY_MHZ = (PLL1_FREQUENCY_MHZ / PLL2_DIV * PLL2_MUL) / PLL2_DIV_0;
    localparam real PLL2_PERIOD_NS     = 1000.000 / PLL2_FREQUENCY_MHZ;

    localparam real VGA_CLK_FREQUENCY_MHZ = PLL2_FREQUENCY_MHZ;
    localparam real VGA_CLK_PERIOD_NS     = PLL2_PERIOD_NS;

`endif

    // --------------------------------------------------------------------------------------------
    // |                                        Simulation                                        |
    // --------------------------------------------------------------------------------------------

    localparam int  SIM_CYCLES_PER_SYS_CLK = int'(SYS_CLK_PERIOD_NS);
    localparam int  SIM_CYCLES_PER_VGA_CLK = int'(VGA_CLK_PERIOD_NS);

endpackage

/*verilator lint_on UNUSED*/
