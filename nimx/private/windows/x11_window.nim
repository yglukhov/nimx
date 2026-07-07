# WebGPU migration: the legacy platform-specific legacy raster backend was removed.
# Native builds use the SDL/WebGPU backend in sdl_window.nim.
import ../../abstract_window
export abstract_window
