#include <math.h>
#include <complex>

using namespace std;

#define FFT_LENGTH 32
#define LOG_FFT_LENGTH 5
#define N FFT_LENGTH
typedef float data_t;
typedef complex<data_t> data_comp;

void FFT(data_comp data_IN[FFT_LENGTH], data_comp data_OUT[FFT_LENGTH]);

const int reversal_index[] = {
    0,16,8,24,4,20,12,28,2,18,10,26,6,22,14,30,1,17,9,25,5,21,13,29,3,19,11,27,7,23,15,31
};

/* 
 * W for fft -- 32/2
 */

const data_comp my_w[FFT_LENGTH/2] = {
    data_comp(cos(2 * M_PI *0/ FFT_LENGTH),-sin(2 * M_PI *0/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *1/ FFT_LENGTH),-sin(2 * M_PI *1/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *2/ FFT_LENGTH),-sin(2 * M_PI *2/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *3/ FFT_LENGTH),-sin(2 * M_PI *3/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *4/ FFT_LENGTH),-sin(2 * M_PI *4/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *5/ FFT_LENGTH),-sin(2 * M_PI *5/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *6/ FFT_LENGTH),-sin(2 * M_PI *6/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *7/ FFT_LENGTH),-sin(2 * M_PI *7/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *8/ FFT_LENGTH),-sin(2 * M_PI *8/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *9/ FFT_LENGTH),-sin(2 * M_PI *9/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *10/ FFT_LENGTH),-sin(2 * M_PI *10/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *11/ FFT_LENGTH),-sin(2 * M_PI *11/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *12/ FFT_LENGTH),-sin(2 * M_PI *12/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *13/ FFT_LENGTH),-sin(2 * M_PI *13/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *14/ FFT_LENGTH),-sin(2 * M_PI *14/ FFT_LENGTH)),
    data_comp(cos(2 * M_PI *15/ FFT_LENGTH),-sin(2 * M_PI *15/ FFT_LENGTH))
};

// function for bit reversal
inline void reverse_bits(data_comp input[N], data_comp output[N]) {
    #pragma HLS RESOURCE variable=reversal_index core=ROM_nP_LUTRAM
    for (int i = 0 ; i < N ; i ++) {
        output[i] = input[reversal_index[i]];
    }
}

// the modular butterfly unit
void baby_bfly(int birth, int death, int shamt1, int shamt2, data_comp input[N], data_comp output[N]) {
    int butterfly_span=0;
    int butterfly_pass=0;
    
    // trying to bind the twiddle factors to a ROM device.
    #pragma HLS RESOURCE variable=my_w core=ROM_nP_LUTRAM
    
    for (int i = 0; i < N/2; i++) {
        #pragma HLS PIPELINE II=4
        #pragma HLS ALLOCATION instances=shl limit=1 operation
        #pragma HLS ALLOCATION instances=add limit=1 operation
        #pragma HLS ALLOCATION instances=mul limit=1 operation
        int index = butterfly_span << shamt1;
        int upper_limit = butterfly_span + (butterfly_pass << shamt2);
        int lower_limit = upper_limit + birth;
        data_comp pprod = my_w[index] * input[lower_limit];
        output[lower_limit] = input[upper_limit] - pprod;
        output[upper_limit] = input[upper_limit] + pprod;

        if (butterfly_span<birth-1){
            butterfly_span++;
        }
        else if (butterfly_pass<death-1) {
            butterfly_span = 0;
            butterfly_pass ++;
        }
        else {
            butterfly_span = 0;
            butterfly_pass = 0;
        }
    }
}


void FFT(data_comp data_IN[N], data_comp data_OUT[N]){
    
#pragma HLS INTERFACE s_axilite port=data_IN bundle=control
#pragma HLS INTERFACE s_axilite port=data_OUT bundle=control
#pragma HLS INTERFACE m_axi port=data_IN bundle=data_IN offset=slave
#pragma HLS INTERFACE m_axi port=data_OUT bundle=data_OUT offset=slave
#pragma HLS INTERFACE s_axilite port=return bundle=control

    static data_comp data_OUT0[N];
    static data_comp data_OUT1[N];
    static data_comp data_OUT2[N];
    static data_comp data_OUT3[N];
    static data_comp data_OUT4[N];
    static data_comp dcbus_inp[N];
    static data_comp dcbus_outp[N];
    
// // handle both real and imag together at ocne - not separately.
#pragma HLS DATA_PACK variable=data_OUT
#pragma HLS DATA_PACK variable=data_IN
// #pragma HLS DATA_PACK variable=dcbus_inp
// #pragma HLS DATA_PACK variable=dcbus_outp

    for (int i=0; i<N; i++) {
        dcbus_inp[i] = data_IN[i];
    }
    reverse_bits(dcbus_inp, data_OUT0);

    baby_bfly(1,  16, 4, 1, data_OUT0, data_OUT1);
    baby_bfly(2,  8,  3, 2, data_OUT1, data_OUT2);
    baby_bfly(4,  4,  2, 3, data_OUT2, data_OUT3);
    baby_bfly(8,  2,  1, 4, data_OUT3, data_OUT4);
    baby_bfly(16, 1,  0, 5, data_OUT4, dcbus_outp);

    for (int i=0; i<N; i++) {
        data_OUT[i] = dcbus_outp[i];
    }
}
