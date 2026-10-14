{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
}:

buildPythonPackage rec {
  pname = "pysword";
  version = "0.2.8";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-YwLzUMIvOQkOJVZylVH6xXpMJc6yaPkM1/0FhLnMpPA=";
  };

  build-system = [ setuptools ];

  pythonImportsCheck = [ "pysword" ];

  meta = {
    description = "Native Python reader for the SWORD Project Bible modules";
    homepage = "https://gitlab.com/tgc-dk/pysword";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ rickprice ];
  };
}
