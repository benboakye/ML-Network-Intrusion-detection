find /tmp/nid_model_extract -type f \( \
-name "nid_random_forest_model.joblib" -o \
-name "label_encoder.joblib" -o \
-name "feature_columns.json" -o \
-name "training_report.txt" \
\) -exec cp {} evidence/ml/ \;
