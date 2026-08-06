# Federated Learning

## Current Status

Federated learning is not implemented in the current semester MVP.

It is documented here as a future privacy-preserving enhancement because LifeLens deals with sensitive lifestyle data such as sleep, spending, workload, and screen time.

## Why Federated Learning Could Help

In a normal ML system, user data is sent to a central server for training. For LifeLens, this creates privacy concerns because the data is personal.

Federated learning would allow:

- Model training on user devices
- Only model updates sent to the server
- Reduced raw data exposure
- Better privacy for lifestyle and financial behavior

## Possible Future Architecture

```text
Android Device A      Android Device B      Android Device C
      |                     |                     |
      | local training      | local training      | local training
      v                     v                     v
  model update          model update          model update
      \                     |                     /
       \                    |                    /
        v                   v                   v
             Aggregation Server
                    |
                    v
             Updated Global Model
                    |
                    v
              Sent Back to Devices
```

## Candidate Use Cases

Federated learning could be used for:

- Burnout risk model improvement
- Overspending risk model improvement
- Recommendation personalization

It should not be used for the current scoring formulas because those are explainable rules.

## Privacy Requirements

If added later, the system should include:

- No raw sleep/spending/screen-time upload for model training
- Secure aggregation
- Differential privacy if possible
- Opt-in consent
- Clear user data controls

## Semester Decision

Federated learning is out of scope for the current project because:

- It requires many real users/devices
- It adds backend aggregation complexity
- It is difficult to verify within one semester
- The current MVP can prove the main LifeLens concept without it

## How To Mention In Presentation

LifeLens is designed so federated learning can be added later as a privacy-focused improvement. The current system first proves data collection, scoring, backend prediction, and recommendation flow.
