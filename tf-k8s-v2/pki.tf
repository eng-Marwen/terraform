# This file creates the Kubernetes certificate authority (CA) before any
# VM boots. The CA is needed to establish trust between the control plane
# and worker nodes during automatic kubeadm bootstrap.
#
# Pre-generating the CA makes a cloud-init-only, no-SSH bootstrap possible:
# Terraform can calculate the CA's discovery hash in advance and place it
# in every worker's cloud-init. Workers use that hash with `kubeadm join` to
# verify that they are joining the expected control plane.
#
# The control-plane cloud-init writes this same CA to
# /etc/kubernetes/pki/ before running `kubeadm init`, so kubeadm reuses it
# instead of generating a different CA. The CA private key is stored in
# Terraform state, so protect terraform.tfstate and do not commit it to a
# public repository.

resource "tls_private_key" "ca" {
  # Select RSA as the algorithm used to generate the CA private key.
  algorithm = "RSA"

  # Generate a 2048-bit RSA key, which provides the CA's private identity.
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  # Sign this certificate with the private key generated above.
  private_key_pem       = tls_private_key.ca.private_key_pem

  # Mark the certificate as a certificate authority that can sign other
  # Kubernetes certificates.
  is_ca_certificate     = true

  # Keep the CA valid for 87,600 hours, or approximately 10 years.
  validity_period_hours = 87600 # 10 years, matches kubeadm's own CA default

  subject {
    # Set the certificate's common name to identify the Kubernetes CA.
    common_name  = "kubernetes"

    # Identify Kubernetes as the organization that owns this certificate.
    organization = "kubernetes"
  }

  # Declare the operations for which this CA certificate may be used.
  allowed_uses = [
    # Permit the CA to sign certificates for cluster components.
    "cert_signing",

    # Permit certificate revocation list signing.
    "crl_signing",

    # Permit signatures used to verify certificate authenticity.
    "digital_signature",

    # Permit encryption of key material during supported TLS operations.
    "key_encipherment",
  ]
}

data "external" "ca_hash" {
  # Run the helper script that calculates kubeadm's CA discovery hash.
  # The external data source reads JSON from the script's standard output.
  program = ["bash", "${path.module}/scripts/ca-hash.sh"]

  # Send the generated certificate to the helper script as JSON input.
  # The script hashes the CA public key, not the private key.
  query = {
    cert_pem = tls_self_signed_cert.ca.cert_pem
  }
}
