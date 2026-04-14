`timescale 1ns / 1ps

module lcd_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    output logic        lcd_rs,
    output logic        lcd_rw,
    output logic        lcd_en,
    output logic [7:0]  lcd_data
);

    assign lcd_rw = 1'b0;

    // Registros de configuracion
    logic       reg_start, reg_rs, reg_clear, reg_home;
    logic [7:0] reg_data;
    logic       flag_busy;

    // FSM
    typedef enum logic [2:0] {
        IDLE, SETUP, ENABLE_HIGH, ENABLE_LOW, WAIT_CMD
    } state_t;
    state_t state_reg, state_next;

    logic [19:0] delay_cnt_reg, delay_cnt_next;

    // Salidas LCD como registros
    logic lcd_rs_reg,  lcd_en_reg;
    logic [7:0] lcd_data_reg;

    assign lcd_rs   = lcd_rs_reg;
    assign lcd_en   = lcd_en_reg;
    assign lcd_data = lcd_data_reg;

    // Declarar next antes de usarlas
    logic lcd_rs_next, lcd_en_next;
    logic [7:0] lcd_data_next;

    // Escritura desde la FSM principal
    // addr 2b00 = CONTROL: bit0=start, bit1=rs, bit2=clear, bit3=home
    // addr 2b01 = DATOS:   bits[7:0] = byte para el LCD
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            reg_start <= 0; reg_rs    <= 0;
            reg_clear <= 0; reg_home  <= 0;
            reg_data  <= 0;
        end else begin
            // Auto-clear de W1P al terminar comando
            if (state_reg == WAIT_CMD && delay_cnt_next == 0)
                {reg_home, reg_clear, reg_start} <= 3'b0;

            if (write_enable_i) begin
                case (addr_i)
                    2'b00: begin
                        reg_start <= wdata_i[0];
                        reg_rs    <= wdata_i[1];
                        reg_clear <= wdata_i[2];
                        reg_home  <= wdata_i[3];
                    end
                    2'b01: reg_data <= wdata_i[7:0];
                    default: ;
                endcase
            end
        end
    end

    // Lectura — busy en bit 8
    always_comb begin
        rdata_o = 32'd0;
        case (addr_i)
            2'b00: rdata_o = {23'd0, flag_busy, 4'd0,
                              reg_home, reg_clear, reg_rs, reg_start};
            2'b01: rdata_o = {24'd0, reg_data};
            default: rdata_o = 32'd0;
        endcase
    end

    // Registros de estado LCD
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_reg     <= IDLE;
            delay_cnt_reg <= 0;
            lcd_rs_reg    <= 0;
            lcd_en_reg    <= 0;
            lcd_data_reg  <= 0;
        end else begin
            state_reg     <= state_next;
            delay_cnt_reg <= delay_cnt_next;
            lcd_rs_reg    <= lcd_rs_next;
            lcd_en_reg    <= lcd_en_next;
            lcd_data_reg  <= lcd_data_next;
        end
    end

    // Logica combinacional FSM LCD
    always_comb begin
        state_next     = state_reg;
        delay_cnt_next = (delay_cnt_reg > 0) ? delay_cnt_reg - 1 : 0;
        lcd_rs_next    = lcd_rs_reg;
        lcd_en_next    = lcd_en_reg;
        lcd_data_next  = lcd_data_reg;
        flag_busy      = 1'b1;

        case (state_reg)
            IDLE: begin
                flag_busy   = 1'b0;
                lcd_en_next = 1'b0;
                if (reg_start || reg_clear || reg_home) begin
                    lcd_rs_next    = (reg_clear || reg_home) ? 1'b0 : reg_rs;
                    lcd_data_next  = reg_clear ? 8'h01 :
                                     (reg_home  ? 8'h02 : reg_data);
                    delay_cnt_next = 20'd10;
                    state_next     = SETUP;
                end
            end
            SETUP: begin
                if (delay_cnt_reg == 0) begin
                    lcd_en_next    = 1'b1;
                    delay_cnt_next = 20'd40;
                    state_next     = ENABLE_HIGH;
                end
            end
            ENABLE_HIGH: begin
                if (delay_cnt_reg == 0) begin
                    lcd_en_next    = 1'b0;
                    delay_cnt_next = 20'd10;
                    state_next     = ENABLE_LOW;
                end
            end
            ENABLE_LOW: begin
                if (delay_cnt_reg == 0) begin
                    delay_cnt_next = (reg_clear || reg_home) ? 20'd30000 : 20'd800;
                    state_next     = WAIT_CMD;
                end
            end
            WAIT_CMD: begin
                if (delay_cnt_reg == 0) state_next = IDLE;
            end
            default: state_next = IDLE;
        endcase
    end

endmodule