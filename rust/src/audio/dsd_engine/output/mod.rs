use super::dsd::dop::DopPacker;
use super::dsd::{DsdOutputMode, DsdRate, FilterQuality};
use super::dsd::DsdDecimationPipeline;
use anyhow::Result;

pub struct DsdOutputRouter {
    mode: DsdOutputMode,
    pcm_pipeline: Option<DsdDecimationPipeline>,
    dop_packer: Option<DopPacker>,
}

impl DsdOutputRouter {
    pub fn new(
        mode: DsdOutputMode,
        dsd_rate: DsdRate,
        target_rate: u32,
        quality: FilterQuality,
        channels: usize,
    ) -> Self {
        let pcm_pipeline = match mode {
            DsdOutputMode::PcmDecimation => {
                Some(DsdDecimationPipeline::new(dsd_rate, target_rate, quality, channels))
            }
            DsdOutputMode::Dop => None,
        };

        let dop_packer = match mode {
            DsdOutputMode::Dop => Some(DopPacker::new(dsd_rate, channels)),
            DsdOutputMode::PcmDecimation => None,
        };

        Self {
            mode,
            pcm_pipeline,
            dop_packer,
        }
    }

    pub fn output_sample_rate(&self, dsd_rate: DsdRate) -> u32 {
        match self.mode {
            DsdOutputMode::PcmDecimation => self
                .pcm_pipeline
                .as_ref()
                .map(|p| p.target_pcm_rate())
                .unwrap_or(dsd_rate.dop_carrier_rate()),
            DsdOutputMode::Dop => dsd_rate.dop_carrier_rate(),
        }
    }

    pub fn mode(&self) -> DsdOutputMode {
        self.mode
    }

    pub fn process_dsd_bytes(
        &mut self,
        dsd_bytes: &[u8],
        channel_offsets: &[usize],
        output: &mut Vec<f32>,
    ) -> Result<()> {
        match self.mode {
            DsdOutputMode::PcmDecimation => {
                if let Some(ref mut pipeline) = self.pcm_pipeline {
                    pipeline.process_bytes(dsd_bytes, channel_offsets, output);
                }
            }
            DsdOutputMode::Dop => {
                if let Some(ref mut packer) = self.dop_packer {
                    packer.pack_to_f32(dsd_bytes, channel_offsets, output);
                }
            }
        }
        Ok(())
    }

    pub fn reset(&mut self) {
        if let Some(ref mut pipeline) = self.pcm_pipeline {
            pipeline.reset();
        }
        if let Some(ref mut packer) = self.dop_packer {
            packer.reset();
        }
    }
}
