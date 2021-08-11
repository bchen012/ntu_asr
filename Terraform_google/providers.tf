provider "google" {
  project = "ntu-asr-317615"
  region  = "asia-southeast1"
  zone    = "asia-southeast1-a"
}

terraform {
  backend "http" {
  }
}