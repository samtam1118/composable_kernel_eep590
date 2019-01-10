#pragma once
#include "constant_tensor_descriptor.cuh"

template <unsigned BlockSize, class Float, class DstDesc, class F>
__device__ void
blockwise_4d_tensor_pointwise_operation_unary(DstDesc, Float* __restrict__ p_dst, F f)
{
    constexpr auto I0 = Number<0>{};
    constexpr auto I1 = Number<1>{};
    constexpr auto I2 = Number<2>{};
    constexpr auto I3 = Number<3>{};

    constexpr auto dst_desc = DstDesc{};

    constexpr auto desc = make_ConstantTensorDescriptor(dst_desc.GetLengths());

#if 0
    if(threadIdx.x == 0)
    {
        print_ConstantTensorDescriptor(dst_desc, "blockwise_4d_tensor_op_unary: dst_desc: ");
        print_ConstantTensorDescriptor(desc, "blockwise_4d_tensor_op_unary: desc: ");
    }
#endif

    constexpr unsigned NLoop = desc.GetElementSize() / BlockSize;

    for(unsigned iloop = 0; iloop < NLoop; ++iloop)
    {
        unsigned is = threadIdx.x + iloop * BlockSize;

        const unsigned did0 = is / desc.GetStride(I0);

        is -= did0 * desc.GetStride(I0);

        const unsigned did1 = is / desc.GetStride(I1);

        is -= did1 * desc.GetStride(I1);

        const unsigned did2 = is / desc.GetStride(I2);

        is -= did2 * desc.GetStride(I2);

        const unsigned did3 = is / desc.GetStride(I3);

        const unsigned dindex = dst_desc.Get1dIndex(did0, did1, did2, did3);

        f(p_dst[dindex]);
    }

    constexpr bool has_tail = (desc.GetElementSize() > NLoop * BlockSize);

    if(has_tail)
    {
        unsigned is = threadIdx.x + NLoop * BlockSize;

        if(is < desc.GetElementSize())
        {
            const unsigned did0 = is / desc.GetStride(I0);

            is -= did0 * desc.GetStride(I0);

            const unsigned did1 = is / desc.GetStride(I1);

            is -= did1 * desc.GetStride(I1);

            const unsigned did2 = is / desc.GetStride(I2);

            is -= did2 * desc.GetStride(I2);

            const unsigned did3 = is / desc.GetStride(I3);

            const unsigned dindex = dst_desc.Get1dIndex(did0, did1, did2, did3);

            f(p_dst[dindex]);
        }
    }
}

// Function: p_dst[reorder[i0], reorder[i1], reorder[i2], reorder[i3]] = p_src[i0,i1,i2,i3]
// TODO: in order to optimize mem access for different mem type,
// need to write specialized version
template <unsigned BlockSize,
          class Float,
          class SrcDesc,
          class DstDesc,
          class RefDesc,
          class Reorder,
          class F>
__device__ void
blockwise_4d_tensor_pointwise_operation_binary_reorder(SrcDesc,
                                                       Float* const __restrict__ p_src,
                                                       DstDesc,
                                                       Float* __restrict__ p_dst,
                                                       RefDesc,
                                                       Reorder,
                                                       F f)
{
    constexpr auto I0 = Number<0>{};
    constexpr auto I1 = Number<1>{};
    constexpr auto I2 = Number<2>{};
    constexpr auto I3 = Number<3>{};

    constexpr unsigned IT0 = Reorder{}.Get(I0);
    constexpr unsigned IT1 = Reorder{}.Get(I1);
    constexpr unsigned IT2 = Reorder{}.Get(I2);
    constexpr unsigned IT3 = Reorder{}.Get(I3);

    constexpr auto src_desc = SrcDesc{};
    constexpr auto dst_desc = DstDesc{};
    constexpr auto ref_desc = RefDesc{};

    constexpr unsigned NLoop = ref_desc.GetElementSize() / BlockSize;

    for(unsigned iloop = 0; iloop < NLoop; ++iloop)
    {
        unsigned is = threadIdx.x + iloop * BlockSize;

        unsigned did[4];

        did[0] = is / ref_desc.GetStride(I0);

        is -= did[0] * ref_desc.GetStride(I0);

        did[1] = is / ref_desc.GetStride(I1);

        is -= did[1] * ref_desc.GetStride(I1);

        did[2] = is / ref_desc.GetStride(I2);

        is -= did[2] * ref_desc.GetStride(I2);

        did[3] = is / ref_desc.GetStride(I3);

        const unsigned aindex = src_desc.Get1dIndex(did[0], did[1], did[2], did[3]);

        const unsigned bindex = dst_desc.Get1dIndex(did[IT0], did[IT1], did[IT2], did[IT3]);

        f(p_src[aindex], p_dst[bindex]);
    }

    constexpr bool has_tail = (ref_desc.GetElementSize() > NLoop * BlockSize);

    if(has_tail)
    {
        unsigned is = threadIdx.x + NLoop * BlockSize;

        if(is < ref_desc.GetElementSize())
        {
            unsigned did[4];

            did[0] = is / ref_desc.GetStride(I0);

            is -= did[0] * ref_desc.GetStride(I0);

            did[1] = is / ref_desc.GetStride(I1);

            is -= did[1] * ref_desc.GetStride(I1);

            did[2] = is / ref_desc.GetStride(I2);

            is -= did[2] * ref_desc.GetStride(I2);

            did[3] = is / ref_desc.GetStride(I3);

            const unsigned aindex = src_desc.Get1dIndex(did[0], did[1], did[2], did[3]);

            const unsigned bindex = dst_desc.Get1dIndex(did[IT0], did[IT1], did[IT2], did[IT3]);

            f(p_src[aindex], p_dst[bindex]);
        }
    }
}

template <unsigned BlockSize, class Float, class DstDesc>
__device__ void blockwise_4d_tensor_set_zero(DstDesc, Float* __restrict__ p_dst)
{
    auto f_set_zero = [](Float& v) { v = Float(0); };

    blockwise_4d_tensor_pointwise_operation_unary<BlockSize>(DstDesc{}, p_dst, f_set_zero);
}

template <unsigned BlockSize,
          class Float,
          class SrcDesc,
          class DstDesc,
          class RefDesc,
          class Reorder>
__device__ void blockwise_4d_tensor_copy_reorder(
    SrcDesc, Float* const __restrict__ p_src, DstDesc, Float* __restrict__ p_dst, RefDesc, Reorder)
{
    auto f_copy = [](const Float& src, Float& dst) { dst = src; };

    blockwise_4d_tensor_pointwise_operation_binary_reorder<BlockSize>(
        SrcDesc{}, p_src, DstDesc{}, p_dst, RefDesc{}, Reorder{}, f_copy);
}

template <unsigned BlockSize, class Float, class SrcDesc, class DstDesc, class RefDesc>
__device__ void blockwise_4d_tensor_copy(
    SrcDesc, Float* const __restrict__ p_src, DstDesc, Float* __restrict__ p_dst, RefDesc)
{
    constexpr auto reorder = Sequence<0, 1, 2, 3>{};

    blockwise_4d_tensor_copy_reorder<BlockSize>(
        SrcDesc{}, p_src, DstDesc{}, p_dst, RefDesc{}, reorder);
}