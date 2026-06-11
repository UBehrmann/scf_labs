------------------------------------------------------------------------------------------
-- HEIG-VD
-- Haute Ecole d'Ingenerie et de Gestion du Canton de Vaud
-- School of Business and Engineering in Canton de Vaud
------------------------------------------------------------------------------------------
-- REDS Institute
-- Reconfigurable Embedded Digital Systems
------------------------------------------------------------------------------------------
--
-- File                 : DE1_SoC_top.vhd
-- Author               : Sébastien Masle
-- Date                 : 17.01.2018
--
-- Context              : HPA
--
------------------------------------------------------------------------------------------
-- Description : top design for DE1-SoC board
--
------------------------------------------------------------------------------------------
-- Dependencies :
--
------------------------------------------------------------------------------------------
-- Modifications :
-- Ver    Date        Engineer      Comments
-- 0.0    17.01.2018  SMS           Initial version.
--
------------------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY DE1_SoC_top IS
    PORT (-- clock pins
        CLOCK_50_i : IN STD_LOGIC;
        CLOCK2_50_i : IN STD_LOGIC;
        CLOCK3_50_i : IN STD_LOGIC;
        CLOCK4_50_i : IN STD_LOGIC;

        -- ADC
        ADC_CS_N_o : OUT STD_LOGIC;
        ADC_DIN_o : OUT STD_LOGIC;
        ADC_DOUT_i : IN STD_LOGIC;
        ADC_SCLK_o : OUT STD_LOGIC;

        -- Audio
        AUD_ADCLRCK_io : INOUT STD_LOGIC;
        AUD_ADCDAT_i : IN STD_LOGIC;
        AUD_DACLRCK_io : INOUT STD_LOGIC;
        AUD_DACDAT_o : OUT STD_LOGIC;
        AUD_XCK_o : OUT STD_LOGIC;
        AUD_BCLK_io : INOUT STD_LOGIC;

        -- SDRAM
        DRAM_ADDR_o : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
        DRAM_BA_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        DRAM_CAS_N_o : OUT STD_LOGIC;
        DRAM_CKE_o : OUT STD_LOGIC;
        DRAM_CLK_o : OUT STD_LOGIC;
        DRAM_CS_N_o : OUT STD_LOGIC;
        DRAM_DQ_io : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        DRAM_LDQM_o : OUT STD_LOGIC;
        DRAM_RAS_N_o : OUT STD_LOGIC;
        DRAM_UDQM_o : OUT STD_LOGIC;
        DRAM_WE_N_o : OUT STD_LOGIC;

        --I2C Bus for Configuration of the Audio and Video-In Chips
        FPGA_I2C_SCLK_o : OUT STD_LOGIC;
        FPGA_I2C_SDAT_io : INOUT STD_LOGIC;

        -- 40-pin headers
        GPIO_0_io : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
        GPIO_1_io : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);

        -- Seven Segment Displays
        HEX0_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX1_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX2_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX3_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX4_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        HEX5_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

        -- IR
        IRDA_RXD_i : IN STD_LOGIC;
        IRDA_TXD_o : OUT STD_LOGIC;

        -- Pushbuttons
        KEY_i : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- LEDs
        LEDR_o : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);

        -- PS2 Ports
        PS2_CLK_io : INOUT STD_LOGIC;
        PS2_DAT_io : INOUT STD_LOGIC;
        PS2_CLK2_io : INOUT STD_LOGIC;
        PS2_DAT2_io : INOUT STD_LOGIC;

        -- Slider Switches
        SW_i : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        -- Video-In
        TD_CLK27_i : IN STD_LOGIC;
        TD_DATA_i : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        TD_HS_i : IN STD_LOGIC;
        TD_RESET_N_o : OUT STD_LOGIC;
        TD_VS_i : IN STD_LOGIC;

        -- VGA
        VGA_R_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        VGA_G_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        VGA_B_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        VGA_CLK_o : OUT STD_LOGIC;
        VGA_SYNC_N_o : OUT STD_LOGIC;
        VGA_BLANK_N_o : OUT STD_LOGIC;
        VGA_HS_o : OUT STD_LOGIC;
        VGA_VS_o : OUT STD_LOGIC;

        -- DDR3 SDRAM
        HPS_DDR3_ADDR_o : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
        HPS_DDR3_BA_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        HPS_DDR3_CAS_N_o : OUT STD_LOGIC;
        HPS_DDR3_CKE_o : OUT STD_LOGIC;
        HPS_DDR3_CK_N_o : OUT STD_LOGIC;
        HPS_DDR3_CK_P_o : OUT STD_LOGIC;
        HPS_DDR3_CS_N_o : OUT STD_LOGIC;
        HPS_DDR3_DM_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        HPS_DDR3_DQ_io : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        HPS_DDR3_DQS_N_io : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        HPS_DDR3_DQS_P_io : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        HPS_DDR3_ODT_o : OUT STD_LOGIC;
        HPS_DDR3_RAS_N_o : OUT STD_LOGIC;
        HPS_DDR3_RESET_N_o : OUT STD_LOGIC;
        HPS_DDR3_RZQ_i : IN STD_LOGIC;
        HPS_DDR3_WE_N_o : OUT STD_LOGIC;

        -- Ethernet
        --HPS_ENET_GTX_CLK_o   : out std_logic;
        --HPS_ENET_INT_N_io    : inout std_logic;
        --HPS_ENET_MDC_o       : out std_logic;
        --HPS_ENET_MDIO_io     : inout std_logic;
        --HPS_ENET_RX_CLK_i    : in std_logic;
        --HPS_ENET_RX_DATA_i   : in std_logic_vector(3 downto 0);
        --HPS_ENET_RX_DV_i     : in std_logic;
        --HPS_ENET_TX_DATA_o   : out std_logic_vector(3 downto 0);
        --HPS_ENET_TX_EN_o     : out std_logic;

        -- Flash
        --HPS_FLASH_DATA_io    : inout std_logic_vector(3 downto 0);
        --HPS_FLASH_DCLK_o     : out std_logic;
        --HPS_FLASH_NCSO_o     : out std_logic;

        -- Accelerometer
        --HPS_GSENSOR_INT_io   : inout std_logic;

        -- General Purpose I/O
        --HPS_GPIO_io          : inout std_logic_vector(1 downto 0);

        -- I2C
        --HPS_I2C_CONTROL_io   : inout std_logic;
        --HPS_I2C1_SCLK_io     : inout std_logic;
        --HPS_I2C1_SDAT_io     : inout std_logic;
        --HPS_I2C2_SCLK_io     : inout std_logic;
        --HPS_I2C2_SDAT_io     : inout std_logic;

        -- Pushbutton
        HPS_KEY_io : INOUT STD_LOGIC;

        -- LED
        HPS_LED_io : INOUT STD_LOGIC;

        -- SD Card
        --HPS_SD_CLK_o         : out std_logic;
        --HPS_SD_CMD_io        : inout std_logic;
        --HPS_SD_DATA_io       : inout std_logic_vector(3 downto 0);

        -- SPI
        --HPS_SPIM_CLK_o       : out std_logic;
        --HPS_SPIM_MISO_i      : in std_logic;
        --HPS_SPIM_MOSI_o      : out std_logic;
        --HPS_SPIM_SS_io       : inout std_logic;

        -- UART
        --HPS_UART_RX_i        : in std_logic;
        --HPS_UART_TX_o        : out std_logic;

        -- USB
        --HPS_CONV_USB_N_io    : inout std_logic;
        --HPS_USB_CLKOUT_i     : in std_logic;
        --HPS_USB_DATA_io      : inout std_logic_vector(7 downto 0);
        --HPS_USB_DIR_i        : in std_logic;
        --HPS_USB_NXT_i        : in std_logic;
        --HPS_USB_STP_o        : out std_logic;

        -- LTC connector
        --HPS_LTC_GPIO_io      : inout std_logic;

        -- FAN
        FAN_CTRL_o : OUT STD_LOGIC
    );
END DE1_SoC_top;

ARCHITECTURE top OF DE1_SoC_top IS

    COMPONENT qsys_system IS
        PORT (
            clk_clk : IN STD_LOGIC := 'X'; -- clk

            -- DDR3 SDRAM
            memory_mem_a : OUT STD_LOGIC_VECTOR(14 DOWNTO 0); -- mem_a
            memory_mem_ba : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); -- mem_ba
            memory_mem_ck : OUT STD_LOGIC; -- mem_ck
            memory_mem_ck_n : OUT STD_LOGIC; -- mem_ck_n
            memory_mem_cke : OUT STD_LOGIC; -- mem_cke
            memory_mem_cs_n : OUT STD_LOGIC; -- mem_cs_n
            memory_mem_ras_n : OUT STD_LOGIC; -- mem_ras_n
            memory_mem_cas_n : OUT STD_LOGIC; -- mem_cas_n
            memory_mem_we_n : OUT STD_LOGIC; -- mem_we_n
            memory_mem_reset_n : OUT STD_LOGIC; -- mem_reset_n
            memory_mem_dq : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => 'X'); -- mem_dq
            memory_mem_dqs : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => 'X'); -- mem_dqs
            memory_mem_dqs_n : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => 'X'); -- mem_dqs_n
            memory_mem_odt : OUT STD_LOGIC; -- mem_odt
            memory_mem_dm : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); -- mem_dm
            memory_oct_rzqin : IN STD_LOGIC := 'X'; -- oct_rzqin

            -- Pushbutton
            hps_io_0_hps_io_gpio_inst_GPIO54 : INOUT STD_LOGIC := 'X'; -- hps_io_gpio_inst_GPIO54

            -- LED
            hps_io_0_hps_io_gpio_inst_GPIO53 : INOUT STD_LOGIC := 'X'; -- hps_io_gpio_inst_GPIO53

            -- AXI4Lite
            input_reg_data_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            input_reg_crcin_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            input_reg_init_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            input_reg_size_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            input_reg_xorout_i : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

            output_reg_crcout_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            output_reg_status_o : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT qsys_system;

    -- IOs declarations
    SIGNAL data_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL crcin_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL init_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL size_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL xorout_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- user outputs
    SIGNAL crcout_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL status_s : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- internal signals
    SIGNAL crc_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL step_s : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL next_s : STD_LOGIC;
    SIGNAL start_s : STD_LOGIC;

    TYPE Type_Etat IS (
        RAZ,
        INIT,
        STEP,
        ENDXOR

    );

    SIGNAL etat_pres, etat_fut : Type_Etat;

BEGIN

    ---------------------------------------------------------
    --  HPS mapping
    ---------------------------------------------------------

    System : COMPONENT qsys_system
        PORT MAP(

            clk_clk => CLOCK_50_i,

            -- DDR3 SDRAM
            memory_mem_a => HPS_DDR3_ADDR_o,
            memory_mem_ba => HPS_DDR3_BA_o,
            memory_mem_ck => HPS_DDR3_CK_P_o,
            memory_mem_ck_n => HPS_DDR3_CK_N_o,
            memory_mem_cke => HPS_DDR3_CKE_o,
            memory_mem_cs_n => HPS_DDR3_CS_N_o,
            memory_mem_ras_n => HPS_DDR3_RAS_N_o,
            memory_mem_cas_n => HPS_DDR3_CAS_N_o,
            memory_mem_we_n => HPS_DDR3_WE_N_o,
            memory_mem_reset_n => HPS_DDR3_RESET_N_o,
            memory_mem_dq => HPS_DDR3_DQ_io,
            memory_mem_dqs => HPS_DDR3_DQS_P_io,
            memory_mem_dqs_n => HPS_DDR3_DQS_N_io,
            memory_mem_odt => HPS_DDR3_ODT_o,
            memory_mem_dm => HPS_DDR3_DM_o,
            memory_oct_rzqin => HPS_DDR3_RZQ_i,

            -- Pushbutton
            hps_io_0_hps_io_gpio_inst_GPIO54 => HPS_KEY_io,

            -- LED
            hps_io_0_hps_io_gpio_inst_GPIO53 => HPS_LED_io,

            -- AXI4Lite
            input_reg_data_i => data_s,
            input_reg_crcin_i => crcin_s,
            input_reg_init_i => init_s,
            input_reg_size_i => size_s,
            input_reg_xorout_i => xorout_s,

            output_reg_crcout_o => crcout_s,
            output_reg_status_o => status_s
        );

        -- start 0x01 dans le status
        start_s <= status_s(0 DOWNTO 0);
        -- next 0x02 dans le satus
        next_s <= status_s(1 DOWNTO 1);

        -- done 0x04 dans status
        status_s(2 DOWNTO 2) <= done_s;

        dec_fut_sor : PROCESS (etat_pres, start_i, end_sh_i)
        BEGIN

            --valeur par defaut des sorties
            done_s <= '0';

            --valeur par defaut etat futur    
            etat_fut <= RAZ;

            --Decodeur d'etats futur et de sorties
            -- Rem: seule les sorties actives sont indiquees dans chaque etat
            CASE etat_pres IS
                WHEN RAZ =>
                    done_s <= '1';
                    --Attente start inactif (pour la detection du flanc)
                    IF (start_s = '0') THEN
                        etat_fut <= ATT_START;
                    ELSE
                        etat_fut <= RAZ;
                    END IF;

                WHEN INIT =>
                    crc_s <= init_s;

                    etat_fut <= STEP;

                WHEN WAIT_NEXT =>

                    IF (next_s = '0') THEN
                        etat_fut <= WAIT_NEXT;
                    ELSE
                        etat_fut <= STEP;
                        -- doit reset status next a 0
                    END IF;

                WHEN STEP =>

                    IF (step_s ! = size_s) THEN
                        crc_s XOR data_s;
                        etat_fut <= WAIT_NEXT;
                    ELSE
                        etat_fut <= ENDXOR;
                    END IF;

                WHEN ENDXOR =>

                    crc_s XOR crcout_s;

                    etat_fut <= RAZ;

                WHEN OTHERS =>
                    etat_fut <= RAZ;
            END CASE;

        END PROCESS dec_fut_sor;

        reg_e : PROCESS (reset_i, clk_i)
        BEGIN
            IF (reset_i = '1') THEN
                etat_pres <= RAZ;
            ELSIF rising_edge(clk_i) THEN
                etat_pres <= etat_fut;
            END IF;
        END PROCESS reg_e;

    END top;