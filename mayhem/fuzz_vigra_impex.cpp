/*
 * fuzz_vigra_impex.cpp — libFuzzer harness for vigra's image import API.
 * Writes fuzz input to /tmp/ then calls vigra::importImage(), exercising
 * the BMP/GIF/PNM/PGM/PNG/JPEG/TIFF format parsers (auto-detected by magic bytes).
 */
#include <stdint.h>
#include <cstdio>
#include <stdexcept>
#include <fstream>
#include <vigra/impex.hxx>
#include <vigra/multi_array.hxx>
#include <vigra/stdimage.hxx>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size == 0)
        return 0;

    // Write input to /dev/shm — always a tmpfs mount, writable even under Mayhem's
    // read-only image filesystem (unlike /tmp which is part of the read-only image layer).
    const char *tmp_path = "/dev/shm/fuzz_vigra_input";
    {
        std::ofstream f(tmp_path, std::ios::binary | std::ios::trunc);
        if (!f.good())
            return 0;
        f.write(reinterpret_cast<const char *>(data), static_cast<std::streamsize>(size));
    }

    try {
        vigra::ImageImportInfo info(tmp_path);
        if (info.isGrayscale()) {
            vigra::MultiArray<2, vigra::UInt8> img(info.width(), info.height());
            vigra::importImage(info, img);
        } else {
            vigra::MultiArray<2, vigra::RGBValue<vigra::UInt8> > img(info.width(), info.height());
            vigra::importImage(info, img);
        }
    } catch (...) {
        // All exceptions expected for malformed inputs — not a crash
    }

    return 0;
}
